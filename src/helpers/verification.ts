import twilio from 'twilio';

import Pool from '@utils/Pool';
import transporter from '@utils/mail';
import { VerificationValue } from '@interfaces/sigt';
import queries from '@utils/queries';
import { QueryResult, Client, PoolClient } from 'pg';
import { errorMessageExtractor } from '@helpers/errors';

const pool = Pool.getInstance();

const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

export const sendRimVerification = async (idRim: number[], value: VerificationValue, payload: string, client: PoolClient) => {
  let alreadyExists;
  const code = Math.random().toString().substring(2, 8);
  console.log('code', code);
  try {
    switch (value) {
      case VerificationValue.Email:
        await Promise.all(
          idRim.map(async (id) => {
            alreadyExists = (await client.query(queries.VERIFY_EXISTING_EMAIL_VERIFICATION, [id])).rowCount > 0;
            if (alreadyExists) {
              throw new Error('Ya hay una verificacion en curso');
            }
            return await client.query(queries.INSERT_EMAIL_VERIFICATION, [id, code]);
          })
        );
        await transporter.sendMail({
          from: 'waku@wakusoftware.com',
          to: payload,
          subject: 'Validación de información',
          text: `Su codigo de verificación es: ${code}`,
          html: `Su codigo de verificación es: <strong>${code}</strong>`,
        });
        break;

      case VerificationValue.CellPhone:
        await Promise.all(
          idRim.map(async (id) => {
            alreadyExists = (await client.query(queries.VERIFY_EXISTING_PHONE_VERIFICATION, [id])).rowCount > 0;
            if (alreadyExists) {
              throw new Error('Ya hay una verificacion en curso');
            }
            return await client.query(queries.INSERT_PHONE_VERIFICATION, [id, code]);
          })
        );
        // await twilioClient.messages.create({
        //   body: `Su codigo de verificación es: ${code}`,
        //   from: process.env.TWILIO_NUMBER,
        //   to: payload,
        // });
        break;
    }
  } catch (e) {
    console.log('fallo', e);
    throw {
      e,
      message: 'Hubo un error en el envio del codigo de verificacion',
    };
  }

  return {
    message: 'Codigo de verificacion enviado.',
  };
};

export const resendCode = async (idRim: string[], value: VerificationValue) => {
  const client = await pool.connect();
  let res;
  let code;
  let email;
  let phone;
  try {
    client.query('BEGIN');
    switch (value) {
      case VerificationValue.Email:
        res = (await client.query(queries.FIND_EMAIL_CODE, [idRim[0]])).rows[0];
        if(res.tiempo.minutes < 10){
          let seconds = +res.tiempo.seconds || 0;
          let minutes = +res.tiempo.minutes || 0;
          throw {
            error: new Error('Debe esperar para reenviar un codigo'),
            tiempo: (10 * 60) - ((minutes * 60) + seconds) 
          }
        }
        code = res.codigo_verificacion;
        email = res.email;
        await transporter.sendMail({
          from: 'waku@wakusoftware.com',
          to: email,
          subject: 'Validación de información',
          text: `Su codigo de verificación es: ${code}`,
          html: `Su codigo de verificación es: <strong>${code}</strong>`,
        });
        break;

      case VerificationValue.CellPhone:
        res = (await client.query(queries.FIND_PHONE_CODE, [idRim[0]])).rows[0];
        code = res.codigo_verificacion;
        phone = res.telefono_celular;
        if(res.tiempo.minutes < 10){
          let seconds = +res.tiempo.seconds || 0;
          let minutes = +res.tiempo.minutes || 0;
          throw {
            error: new Error('Debe esperar para reenviar un codigo'),
            tiempo: (10 * 60) - ((minutes * 60) + seconds) 
          }
        }
        await twilioClient.messages.create({
          body: `Su codigo de verificación es: ${code}`,
          from: process.env.TWILIO_NUMBER,
          to: phone,
        });
        break;
    }
    client.query('COMMIT');
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      e,
      message: 'Error en el reenvio del código',
    };
  } finally {
    client.release();
  }

  return {
    message: 'Codigo de verificacion reenviado.',
  };
};

export const verifyCode = async (idRim: string[], value: VerificationValue, code: string) => {
  const client = await pool.connect();
  let res: QueryResult[];
  let verificationId;
  let valid;
  try {
    client.query('BEGIN');
    switch (value) {
      case VerificationValue.Email:
        res = await Promise.all(
          idRim.map((id) => {
            return client.query(queries.VALIDATE_EMAIL_VERIFICATION, [id, code]);
          })
        );
        break;

      case VerificationValue.CellPhone:
        res = await Promise.all(
          idRim.map((id) => {
            return client.query(queries.VALIDATE_PHONE_VERIFICATION, [id, code]);
          })
        );
        break;
    }
    valid = res.every((row) => row.rowCount > 0);

    if (valid) {
      switch (value) {
        case VerificationValue.Email:
          await Promise.all(
            res.map((qr) => {
              verificationId = qr.rows[0].id_verificacion_email;
              return client.query(queries.DISABLE_EMAIL_VERIFICATION, [verificationId]);
            })
          );
          break;

        case VerificationValue.CellPhone:
          await Promise.all(
            res.map((qr) => {
              verificationId = qr.rows[0].id_verificacion_telefono;
              return client.query(queries.DISABLE_PHONE_VERIFICATION, [verificationId]);
            })
          );

          break;
      }
    } else {
      throw new Error('Información inválida');
    }
    client.query('COMMIT');
    return {
      message: 'Codigo de verificacion aceptado.',
    };
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
