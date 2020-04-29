import { EventEmitter } from 'events';
import { renderFile } from 'pug';
import { resolve } from 'path';

import transporter from '@utils/mail';

class MailProcedureEventEmitter extends EventEmitter {}

const emitter = new MailProcedureEventEmitter();

const viewsDir = resolve(__dirname, '../../views');

const statesMap = {
  'creado': 'creada',
  'iniciado': 'iniciada',
  'validando': 'puesta en validación',
  'ingresardatos': 'puesta en espera por ingreso de datos',
  'enproceso': 'puesta en proceso',
  'enrevision': 'puesta en revisión',
  'porrevisar': 'puesta en espera para una revisión',
  'visto': 'vista',
  'aprobado': 'aprobada',
  'negado': 'aprobado',
  'atendido': 'atendida',
  'finalizado': 'finalizada'
}

emitter.on('procedureEventUpdated', ({ codigo, emailUsuario, nombreCompletoUsuario, nombreTipoTramite, nombreCortoInstitucion, status }) => {
  setImmediate(() => {
    status = statesMap[status] ? statesMap[status] : status;
    transporter.sendMail({
      from: 'waku@wakusoftware.com',
      to: emailUsuario,
      subject: `ACTUALIZACION DE INFORMACION EXPEDIENTE N°${codigo} ${nombreCortoInstitucion}`,
      html: renderFile(resolve(viewsDir, nombreTipoTramite !== 'Multa' ? 'main.pug' : 'main_multa.pug'), {
        codigo,
        nombreCompletoUsuario,
        nombreTipoTramite,
        nombreCortoInstitucion,
        status,
        cache: true,
        moment: require('moment'),
      }),
    });
  });
});

export const sendEmail = (procedure) => {
  const mailData = {
    codigo: procedure.codigo,
    emailUsuario: procedure.nombreUsuario,
    nombreCompletoUsuario: procedure.nombreCompletoUsuario,
    nombreTipoTramite: procedure.nombreTramiteLargo,
    nombreCortoInstitucion: procedure.nombreCorto,
    status: procedure.estado,
  };
  emitter.emit('procedureEventUpdated', mailData);
};

export default emitter;


