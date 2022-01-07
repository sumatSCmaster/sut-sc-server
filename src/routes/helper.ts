import { Router } from 'express';
import { mainLogger } from '@utils/logger';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { patchSettlement } from '@helpers/settlement';

const router = Router();

const pool = Pool.getInstance();

const GET_CONTRIBUTORS_WITHOUT_LIQUIDATIONS: string =
  'SELECT * FROM impuesto.liquidacion WHERE id_subramo IN (9, 103, 229) AND fecha_liquidacion >= $1 AND id_registro_municipal IN (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE id_contribuyente IN (SELECT DISTINCT(id_contribuyente) FROM impuesto.solicitud WHERE id_solicitud IN (SELECT id_procedimiento FROM pago WHERE id_procedimiento IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_solicitud NOT IN (SELECT DISTINCT(id_solicitud) FROM impuesto.solicitud JOIN impuesto.liquidacion USING (id_solicitud))) AND concepto = $2 AND aprobado = true)));';
router.get('/fix_liquidaciones', async (req, res) => {
  try {
    const client = await pool.connect();
    let contributors = (await client.query(GET_CONTRIBUTORS_WITHOUT_LIQUIDATIONS, ['2021-12-15', 'IMPUESTO'])).rows;
    if (!contributors) {
      throw res.status(404).json({
        ok: false,
        data: 'There are no data',
      });
    }
    for (const contributor of contributors) {
      const { id_solicitud: id, fecha_liquidacion: fechaLiquidacion, id_subramo: subramo } = contributor;
      const settlement = { fechaLiquidacion, subramo, estado: 'finalizado' };
      await patchSettlement({ id, settlement });
    }

    return res.status(201).json({
      ok: true,
      data: contributors,
    });
  } catch (e) {
    return e;
  }
});

export default router;
