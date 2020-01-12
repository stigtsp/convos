/**
 * Api can send and retrieve information from the WebSocket.
 *
 * @exports Api
 * @class Api
 * @property {String} url An URL to a WebSocket endpoint.
 * @see Operation
 */

import Operation from '../store/Operation';

export default class Api {
  constructor(url) {
    this.protocol = location.protocol;
    this.url = url;
  }

  /**
   * operation() is used to create a new {@link Operation} object by operation
   * ID.
   *
   * @example
   * const getUserOp = api.operation('getUser');
   * const getUserOp = api.operation('getUser', {connections: true});
   *
   * @memberof Api
   * @param {String} operationId An operation ID in the spec.
   * @param {Object} defaultParams An Object holding default "Operation" parameters. (optional)
   * @returns An Operation object.
   */
  operation(name, defaultParams) {
    const op = new Operation({api: this, name, defaultParams});
    op.req.headers = {'Content-Type': 'application/json'};
    return op;
  }
}
