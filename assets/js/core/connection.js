(function(window) {
  Convos.Connection = function(attrs) {
    this._state = 'disconnected';
    this._api = Convos.api;
    riot.observable(this);
    if (attrs) this.update(attrs);
  };

  var proto = Convos.Connection.prototype;

  // Define attributes
  mixin.base(proto, {
    id: function() { return ''; },
    name: function() { return ''; },
    url: function() { return new riot.Url(); },
    user: function() { throw 'user cannot be built'; }
  });

  // Join a room or create a private conversation on the server
  proto.joinConversation = function(name, cb) {
    var self = this;
    this._api.joinConversation(
      {body: {name: name}, connection_id: this.id()},
      function(err, xhr) {
        if (!err) self.user().conversation(xhr.body);
        cb.call(self, err, xhr.body);
      }
    );
    return this;
  };

  // Return protocol (scheme) from url()
  proto.protocol = function() {
    var url = this.url();
    var r = url.scheme.apply(url, arguments);
    return r == url ? this : r;
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    var self = this;
    this._api.roomsByConnection(
      {connection_id: this.id()},
      function(err, xhr) {
        if (err) return cb.call(self, err, []);
        cb.call(self, err, $.map(xhr.body.rooms, function(attrs) { return new Convos.ConversationRoom(attrs); }));
      }
    );
    return this;
  };

  // Write connection settings to server
  proto.save = function(cb) {
    var self = this;
    var attrs = {url: this.url().toString()}; // It is currently not possible to specify "name"

    if (this.id()) {
      this._api.updateConnection(
        {body: attrs, connection_id: this.id()},
        function(err, xhr) {
          if (err) return cb.call(self, err);
          self.update(xhr.body);
          cb.call(self, err);
        }
      );
    }
    else {
      this._api.createConnection({body: attrs}, function(err, xhr) {
        if (err) return cb.call(self, err);
        self.update(xhr.body);
        self.user().connection(self);
        cb.call(self, err);
      });
    }
    return this;
  };

  // override base.update() to make sure we don't mess up url()
  var update = proto.update;
  proto.update = function(attrs) {
    var url = this.url();
    update.call(this, attrs);
    if (attrs.state) this._state = attrs.state;
    if (attrs.url && typeof attrs.url == 'string') url.parse(attrs.url);
    return this.url(url);
  };

  // Change state to "connected" or "disconnected"
  // Can also be used to retrieve state: "connected", "disconnected" or "connecting"
  proto.state = function(state, cb) {
    if (!cb) return this._state;
    throw 'TODO';
  };
})(window);