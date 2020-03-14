import { EventEmitter } from 'events';
import { renderFile } from 'pug';
import { resolve } from 'path';

import transporter from '@utils/mail';

class MailProcedureEventEmitter extends EventEmitter {}

const emitter = new MailProcedureEventEmitter();

const viewsDir = resolve(__dirname, '../../views');

emitter.on('procedureEventUpdated', ({ codigoTramite, emailUsuario, nombreCompletoUsuario, nombreTipoTramite, nombreCortoInstitucion, status }) => {
    setImmediate(() => {
        transporter.sendMail({
            from: 'waku@wakusoftware.com',
            to: emailUsuario,
            subject: `ACTUALIZACION DE INFORMACION EXPEDIENTE N°${codigoTramite} ${nombreCortoInstitucion}`,
            html: renderFile(resolve(viewsDir, 'main.pug'), {codigoTramite, nombreCompletoUsuario, nombreTipoTramite, nombreCortoInstitucion, status, cache: true})
        })
    });
});

export default emitter;