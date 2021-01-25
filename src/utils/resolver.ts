/**
 *
 * @param promise
 */
export const fulfill = async (promise): Promise<any[]> => {
  try {
    const response = await promise;
    return [null, response];
  } catch (e) {
    return [e];
  }
};
