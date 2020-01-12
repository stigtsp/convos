/**
 * Operation represents a message that is sent/received over a WebSocket.
 *
 * @exports Operation
 * @class Operation
 * @extends Reactive
 * @property {Api} api An {@link Api} object.
 * @property {Object} defaultParams An Object holding default "Operation" parameters. (optional)
 * @property {Object} req The requested data sent to the WebSocket.
 * @property {Object} res The response from the WebSocket.
 * @property {String} id The name of the operation ID.
 * @property {String} status Either "error", "loading", "pending" or "success".
 * @see Api
 */

import Reactive from '../js/Reactive';
import {q, regexpEscape} from '../js/util';

export default class Operation extends Reactive {
  constructor(params) {
    super();

    this.prop('ro', 'api', params.api);
    this.prop('ro', 'defaultParams', params.defaultParams || {});
    this.prop('ro', 'name', params.name || params.id);
    this.prop('ro', 'req', {});
    this.prop('ro', 'res', {});
    this.prop('rw', 'status', 'pending');
  }

  /**
   * error() can be used to get the first error.
   *
   * @returns {String} A descriptive error string.
   */
  error() {
    const err = this.res && this.res.errors && this.res.errors[0];
    if (!err) return '';
    const path = err.path && err.path.match(/\w$/) && err.path.split('/').pop();
    return path ? path + ': ' + err.message : err.message;
  }

  /**
   * perform() is used to send/receive data over a WebSocket.
   *
   * @example
   * await op.perform({email: 'jhthorsen@cpan.org'});
   * console.log(op.res.body);
   *
   * @memberof Operation
   * @param {Object} params Mapping between request parameter names and values.
   * @param {HTMLFormElement} params A form with parameter names and values.
   * @returns {Promise} The promise will be resolved on error and success.
   */
  perform(params) {
    if (this._promise) return this._promise; // this._promise is used as a locking mechanism so you can only call perform() once
    this.update({status: 'loading'});
    const req = this._paramsToRequest(params || this.defaultParams);
    this.emit('start', req);
    if (typeof req == 'object' && typeof req.has != 'function') req = JSON.stringify(req);
    return (this._promise = this.api.send(req).then(res => this._parse(res)));
  }

  /**
   * is() can be used to check if the Operation is in a given state.
   *
   * @memberof Operation
   * @param {String} status Either "error", "loading", "pending" or "success".
   * @retuns {Boolean} True/false if the "status" property matches the input "status".
   */
  is(status) {
    return this.status == status;
  }

  /**
   * reset() can be used to clear the response with any data previously fetched.
   *
   * @memberof Operation
   */
  reset() {
    return this.update({res: {status: 0}, status: 'pending'});
  }

  _paramsToRequest(params) {
    if ((params.tagName || '').toLowerCase() == 'form') {
      params = q(params, 'input').reduce((map, el) => {
        if (el.name) map[el.name] = el.value;
        return map;
      });
    }

    params.method = this.name;
    return params;
  }

  _parse(res) {
    this.res = res || {};
    delete this._promise;
    return this.update({res, status: res.errors ? 'error' : 'success'});
  }
}
