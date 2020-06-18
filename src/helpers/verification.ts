import twilio from 'twilio';

import Pool from '@utils/Pool';
import transporter from '@utils/mail';
import { VerificationValue } from '@interfaces/sigt';
import queries from '@utils/queries';
import { QueryResult } from 'pg';
import { errorMessageExtractor } from '@helpers/errors'

const pool = Pool.getInstance();

const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

export const sendRimVerification = async (idRim: string, value: VerificationValue, payload: string) => {
  const client = await pool.connect();
  let alreadyExists;
  const code = Math.random().toString().substring(2, 8);
  console.log('code', code);
  try {
    client.query('BEGIN');
    switch (value) {
      case VerificationValue.Email:
        alreadyExists = (await client.query(queries.VERIFY_EXISTING_EMAIL_VERIFICATION, [idRim])).rowCount > 0;
        if (alreadyExists) {
          throw new Error('Ya hay una verificacion en curso');
        }
        await client.query(queries.INSERT_EMAIL_VERIFICATION, [idRim, code]);
        await transporter.sendMail({
          from: 'waku@wakusoftware.com',
          to: payload,
          subject: 'Validación de información',
          text: `Su codigo de verificación es: ${code}`,
          html: `Su codigo de verificación es: <strong>${code}</strong>`,
        });
        break;

      case VerificationValue.CellPhone:
        alreadyExists = (await client.query(queries.VERIFY_EXISTING_PHONE_VERIFICATION, [idRim])).rowCount > 0;
        if (alreadyExists) {
          throw new Error('Ya hay una verificacion en curso');
        }
        await client.query(queries.INSERT_PHONE_VERIFICATION, [idRim, code]);
        await twilioClient.messages.create({
          body: `Su codigo de verificación es: ${code}`,
          from: process.env.TWILIO_NUMBER,
          to: payload,
        });
        break;
    }
    client.query('COMMIT');
  } catch (e) {
    client.query('ROLLBACK');
    console.log('fallo', e);
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

export const resendCode = async (idRim: string, value: VerificationValue) => {
  const client = await pool.connect();
  let res;
  let code;
  let email;
  let phone;
  try {
    switch (value) {
      case VerificationValue.Email:
        res = (await client.query(queries.FIND_EMAIL_CODE, [idRim])).rows[0];
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
        res = (await client.query(queries.FIND_PHONE_CODE, [idRim])).rows[0];
        code = res.codigo_verificacion;
        phone = res.telefono_celular;
        await twilioClient.messages.create({
          body: `Su codigo de verificación es: ${code}`,
          from: process.env.TWILIO_NUMBER,
          to: phone,
        });
        break;
    }
  } catch (e) {
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

export const verifyCode = async (idRim: string, value: VerificationValue, code: string) => {
  const client = await pool.connect();
  let res: QueryResult;
  let verificationId;
  let valid;
  try {
    switch (value) {
      case VerificationValue.Email:
        res = await client.query(queries.VALIDATE_EMAIL_VERIFICATION, [idRim, code]);
        break;

      case VerificationValue.CellPhone:
        res = await client.query(queries.VALIDATE_PHONE_VERIFICATION, [idRim, code]);
        break;
    }
    valid = res.rowCount > 0;

    if (valid) {
      verificationId = value === VerificationValue.Email ? res.rows[0].id_verificacion_email : res.rows[0].id_verificacion_telefono;
      switch (value) {
        case VerificationValue.Email:
          await client.query(queries.DISABLE_EMAIL_VERIFICATION, [verificationId]);
          break;

        case VerificationValue.CellPhone:
          await client.query(queries.DISABLE_PHONE_VERIFICATION, [verificationId]);
          break;
      }
    } else {
      throw new Error('Información inválida');
    }
    return {
      message: 'Codigo de verificacion aceptado.',
    };
  } catch (e) {
    console.log(e);
    throw {
      e,
      message: 'Hubo un error en la verificacion',
    };
  } finally {
    client.release();
  }
};
