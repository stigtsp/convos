<script>
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount, tick} from 'svelte';
import {gotoUrl, urlToForm} from '../store/router';
import {l, lmd} from '../js/i18n';

export let dialog = {};

const settings = getContext('settings');
const user = getContext('user');
const createConnectionOp = user.api.operation('createConnection');
const removeConnectionOp = user.api.operation('removeConnection');
const updateConnectionOp = user.api.operation('updateConnection');

[createConnectionOp, updateConnectionOp].forEach(op => {
  op.on('start', req => {
    req.body.on_connect_commands = req.body.on_connect_commands.split('\n').map(str => str.trim());
  });
});

let connection = {};
let formEl;
let showAdvancedSettings = false;
let useTls = false;
let verifyTls = false;
let wantToBeConnected = false;

$: if (formEl) formEl.wanted_state.value = wantToBeConnected ? 'connected' : 'disconnected';

onMount(async () => {
  if (!formEl) return; // if unMounted while loading user data
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
  return connection.url ? connectionToForm() : defaultsToForm();
});

function defaultsToForm() {
  if (settings.forced_connection) formEl.server.value = settings.default_connection;
  formEl.nick.value = user.email.replace(/@.*/, '').replace(/\W/g, '_');
  useTls = true;
  wantToBeConnected = true;
  urlToForm(formEl);
}

function connectionToForm() {
  if (!connection.url) return; // Could not find connection
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.on_connect_commands.value = connection.on_connect_commands.join('\n');
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
  useTls = connection.url.searchParams.get('tls') == '1' && true || false;
  verifyTls = connection.url.searchParams.get('tls_verify') == '1' && true || false;
  wantToBeConnected = connection.wanted_state == 'connected';
}

async function removeConnection(e) {
  await removeConnectionOp.perform(connection);
  user.removeDialog(connection);
  gotoUrl('/chat');
}

async function submitForm(e) {
  if (!formEl.server.value) return; // TODO: Inform that it is required

  formEl.url.value = new ConnURL('irc://localhost:6667').fromForm(e.target).toString();

  if (connection.connection_id) {
    await updateConnectionOp.perform(e.target);
    user.ensureDialog(updateConnectionOp.res.body);
    connectionToForm();
  }
  else {
    await createConnectionOp.perform(e.target);
    const conn = user.ensureDialog(createConnectionOp.res.body);
    gotoUrl(conn.path);
  }
}
</script>

<form method="post" bind:this="{formEl}" on:submit|preventDefault="{submitForm}">
  {#if connection.connection_id}
    <input type="hidden" name="connection_id" value="{connection.connection_id}">
  {/if}
  <input type="hidden" name="url">
  <input type="hidden" name="wanted_state">

  <TextField name="server" placeholder="{l('Ex: chat.freenode.net:6697')}" readonly="{settings.forced_connection}">
    <span slot="label">{l('Host and port')}</span>
  </TextField>

  {#if settings.forced_connection}
    <p>{@html lmd('Connection is locked by %1.', settings.contact)}</p>
  {/if}

  <TextField name="nick" placeholder="{l('Ex: your-name')}">
    <span slot="label">{l('Nickname')}</span>
  </TextField>
  {#if connection.url}
    <Checkbox bind:checked="{wantToBeConnected}">
      <span slot="label">{l('Want to be connected')}</span>
    </Checkbox>
  {/if}
  <Checkbox name="tls" bind:checked="{useTls}">
    <span slot="label">{l('Secure connection (TLS)')}</span>
  </Checkbox>
  {#if useTls}
    <Checkbox name="tls_verify" bind:checked="{verifyTls}">
      <span slot="label">{l('Verify certificate (TLS)')}</span>
    </Checkbox>
  {/if}
  <Checkbox bind:checked="{showAdvancedSettings}">
    <span slot="label">{l('Show advanced settings')}</span>
  </Checkbox>
  <TextField name="username" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('Username')}</span>
  </TextField>
  <PasswordField name="password" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('Password')}</span>
  </PasswordField>
  <TextArea name="on_connect_commands" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('On-connect commands')}</span>
  </TextArea>
  <div class="form-actions">
    {#if connection.url}
      <Button icon="save" op="{updateConnectionOp}">{l('Update')}</Button>
      <Button icon="trash" type="button" op="{removeConnectionOp}" on:click="{removeConnection}">{l('Delete')}</Button>
    {:else}
      <Button icon="save" op="{createConnectionOp}">{l('Create')}</Button>
    {/if}
  </div>
  <OperationStatus op="{createConnectionOp}"/>
  <OperationStatus op="{removeConnectionOp}"/>
  <OperationStatus op="{updateConnectionOp}"/>
</form>