import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { errorMessageGenerator } from "./errors";
import { createTransport, createTestAccount } from 'nodemailer'
import { v4 as uuidv4 } from 'uuid';
import { genSalt, hash } from "bcryptjs";
const pool = Pool.getInstance();


let transporter = createTransport({
    pool: true,
    host: 'smtp.ethereal.email',
    port: 587,
    auth: {
        user: 'marcia22@ethereal.email',
        pass: 'ymY3GE7ZMkbYM4nDdP'
    },
});


export const forgotPassword = async (email) => {
    const client = await pool.connect();
    try{
        const emailExists = (await client.query(queries.EMAIL_EXISTS, [email])).rowCount > 0;
        if(emailExists) {
            const recuperacion = (await client.query(queries.ADD_PASSWORD_RECOVERY, [email, uuidv4()])).rows[0];
            await transporter.sendMail({
                from: 'waku@wakusoftware.com',
                to: email,
                subject: 'Recuperación de contraseña',
                text: `Enlace de recuperacion: ${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}`,
                html: `Enlace de recuperacion: <a>${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}</a>`
            })
            return { status: 200, message: 'Revise su bandeja de correo' }
        }else{
            return { status: 404, message: 'Información inválida'}
        }
    } catch (e) {
        throw {
            status: 500,
            error: e,
            message: errorMessageGenerator(e) || "Error al iniciar proceso de recuperación"
        }
    } finally {
        client.release();
    }
}

export const recoverPassword = async (recoverToken, password) => {
    const client = await pool.connect();
    try{
        client.query('BEGIN');
        const validToken = (await client.query(queries.VALIDATE_TOKEN, [recoverToken])).rowCount > 0;
        (await client.query(queries.DISABLE_TOKEN, [recoverToken]));
        if(validToken){
            const salt = await genSalt(10);
            const newPassword = await hash(password, salt);
            const result = (await client.query(queries.UPDATE_PASSWORD, [recoverToken, newPassword]));
            client.query('COMMIT');
            return { status: 200, message: 'Contraseña actualizada' };
        } else {
            return { status: 409, message: 'El enlace utilizado ya es invalido' };
        }
    } catch (e) {
        client.query('ROLLBACK');
        throw {
            status: 500,
            error: e,
            message: errorMessageGenerator(e) || "Error al iniciar proceso de recuperación"
        }
    } finally {
        client.release();
    }
}


async function ola() {
    console.log(await transporter.verify())
    await transporter.sendMail({
        from: 'waku@wakusoftware.com',
        to: 'marcia22@ethereal.mail',
        subject: 'contrasena',
        text: 'hola',
        html: '<h1>OLA</h1>'
    })
}
