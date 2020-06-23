import twilio from 'twilio';

import Pool from '@utils/Pool';
import transporter from '@utils/mail';
import { VerificationValue } from '@interfaces/sigt';
import queries from '@utils/queries';
import { QueryResult, Client, PoolClient } from 'pg';
import { errorMessageExtractor } from '@helpers/errors';

const pool = Pool.getInstance();

const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

const generateCode = () => {
  return Math.random().toString().substring(2, 8);
};

export const sendRimVerification = async (value: VerificationValue, payload: { idRim: number[]; content: string; user: number }) => {
  const client = await pool.connect();
  let code = generateCode();
  console.log('code', code);
  try {
    await client.query('BEGIN');
    switch (value) {
      case VerificationValue.CellPhone:
        const exists = await client.query(queries.CHECK_VERIFICATION_EXISTS, [payload.user]);
        if(exists.rowCount > 0){
          const verificationRow = exists.rows[0];
          if(!verificationRow.late) {
            const minutes = +verificationRow.elapsed.minutes || 0;
            const seconds = +verificationRow.elapsed.seconds || 0;
            throw {
              error: new Error('Debe esperar para enviar un código'),
              tiempo: 10 * 60 - (minutes * 60 + seconds)
            }
          }
        }
        await client.query(queries.DROP_EXISTING_VERIFICATION, [payload.user])
        const verification = (await client.query(queries.CREATE_VERIFICATION, [code, payload.user])).rows[0];
        await Promise.all(
          payload.idRim.map(async (id) => {
            await client.query(queries.ADD_PHONE_TO_VERIFICATION, [id, verification.id_verificacion_telefono]);
          })
        );
        // await twilioClient.messages.create({
        //   body: `Su codigo de verificación es: ${code}`,
        //   from: process.env.TWILIO_NUMBER,
        //   to: payload.content,
        // });
        break;
    }
    await client.query('COMMIT');
  } catch (e) {
    console.log('fallo', e);
    await client.query('ROLLBACK');
    throw {
      e,
      message: 'Hubo un error en el envio del codigo de verificacion',
    };
  } finally {
    client.release();
  }

  return {
    message: 'Codigo de verificacion enviado.',
  };
};

export const resendCode = async (value: VerificationValue, payload: { user: number }) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    switch (value) {
      case VerificationValue.CellPhone:
        const verification = await client.query(queries.GET_VERIFICATION, [payload.user]);
        if (verification.rowCount === 0) {
          throw new Error('No se ha hallado un proceso de verificación en proceso');
        } else {
          const verificationRow = verification.rows[0];
          if (!verificationRow.late) {
            const minutes = +verificationRow.elapsed.minutes || 0;
            const seconds = +verificationRow.elapsed.seconds || 0;
            throw {
              error: new Error('Debe esperar para enviar un código'),
              tiempo: 10 * 60 - (minutes * 60 + seconds),
            };
          } else {
            let code = generateCode();
            console.log(code);
            await client.query(queries.UPDATE_CODE, [code, payload.user]);
            // await twilioClient.messages.create({
            //   body: `Su codigo de verificación es: ${code}`,
            //   from: process.env.TWILIO_NUMBER,
            //   to: phone,
            // });
            return {
              message: 'Código reenviado',
            };
          }
        }
    }
    client.query('COMMIT');
  } catch (e) {
    console.log(e);
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }

  return {
    message: 'Codigo de verificacion reenviado.',
  };
};

export const verifyCode = async (value: VerificationValue, payload: { code: string; user: number }) => {
  const client = await pool.connect();
  let result;
  try {
    client.query('BEGIN');
    const verification = await client.query(queries.GET_VERIFICATION, [payload.user]);
    console.log(payload.code, verification.rows[0]);
    if (verification.rowCount === 0) {
      throw new Error('No se ha hallado un proceso de verificación en proceso');
    } else if (verification.rows[0].late) {
      throw new Error('Su código de verificación ha caducado, debe pedir un reenvio');
    } else if (payload.code.trim() === verification.rows[0].codigo_verificacion) {
      await client.query(queries.VALIDATE_CODE, [payload.user]);
      result = {
        message: 'Su código ha sido verificado con éxito.',
      };
    } else {
      throw new Error('Código inválido');
    }
    client.query('COMMIT');
    return result;
  } catch (e) {
    client.query('ROLLBACK');
    console.log(e);
    throw {
      e,
      message: 'Hubo un error en la verificacion',
    };
  } finally {
    client.release();
  }
};
