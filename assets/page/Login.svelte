<script>
import Button from '../components/form/Button.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import Scrollspy from '../js/Scrollspy';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {q} from '../js/util';
import {route} from '../store/Route';

const emailFromParams = location.href.indexOf('email=') != -1;
const user = getContext('user');
const scrollspy = new Scrollspy();
const loginOp = user.api.operation('loginUser');
const registerOp = user.api.operation('registerUser');

let formEl;
let mainEl;
let observer;

$: defaultPos = $route.path.indexOf('register') == -1 ? 0 : '#signup';
$: scrollspy.wrapper = mainEl;
$: scrollspy.scrollTo($route.hash ? '#' + $route.hash : 0);

$: if ($loginOp.is('success')) {
  redirectAfterLogin(loginOp);
}

$: if ($registerOp.is('success')) {
  route.update({lastUrl: ''}); // Make sure the old value is forgotten
  redirectAfterLogin(registerOp);
}

onMount(() => {
  if (!observer) {
    const threshold = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
    observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const ratio = entry.intersectionRatio;
        entry.target.style.opacity = ratio > 0.9 ? 1 : ratio ? (ratio - 0.25) : 1;
      });
    }, {threshold});
    q(document, '.fade-in', el => observer.observe(el));
  }

  if (formEl) route.urlToForm(formEl);
});

async function redirectAfterLogin(op) {
  op.reset();
  await user.load();
  return user.is('authenticated') ? route.go('/') : location.reload();
}
</script>

<main id="top" bind:this="{mainEl}">
  <div class="hero-wrapper">
    <header class="hero">
      <div class="hero--text">
        <h1>
          <img src="{route.urlFor('/images/convos-light.png')}" alt="Convos">
          <small class="tagline">&mdash; A better chat experience</small>
          <small>Convos is the simplest way to use IRC and it is always online.</small>
        </h1>
        <p class="hero-cta">
          <a class="btn" on:click="{scrollspy.scrollTo}" href="#signup"><Icon name="user-plus"/> {l('Sign up')}</a>
          <a class="btn" on:click="{scrollspy.scrollTo}" href="#signin"><Icon name="sign-in-alt"/> {l('Sign in')}</a>
        </p>
        <nav>
          <a href="https://convos.chat">About</a>
          <a href="https://convos.chat/blog">Blog</a>
          <a href="https://github.com/nordaaker/convos/"><Icon family="brand" name="github"/></a>
          <a href="https://twitter.com/convosby/"><Icon family="brand" name="twitter"/></a>
        </nav>
      </div>
      <a href="#instant-demo" class="hero--media">
        <img src="{route.urlFor('/screenshots/2020-05-28-convos-chat.jpg')}" alt="Picture of Convos conversation">
      </a>
    </header>
  </div>

  <section id="signup" class="has-max-width">
    {#if process.env.status >= 400}
      <h2>{l('Invalid invite/recover URL')}</h2>
      <p>{l(process.env.status == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
      <p>{l('Please ask your Convos admin for a new link.')}</p>
      <p>
        <a class="btn" href="{process.env.contact}">{l('Contact admin')}</a>
      </p>
    {:else if emailFromParams || process.env.open_to_public || $user.isFirst}
      <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
        <h2>{l(process.env.existing_user ? 'Recover account' : 'Sign up')}</h2>
        {#if $user.isFirst}
          <p>{l('As you are the first user, you do not need any invitation link. Just fill in the form below, hit "Sign up" to start chatting.')}</p>
        {/if}
        <input type="hidden" name="exp">
        <input type="hidden" name="token">

        <TextField type="email" name="email" placeholder="{l('Ex: john@doe.com')}" readonly="{emailFromParams}" bind:value="{user.formEmail}">
          <span slot="label">{l('E-mail')}</span>
          <p class="help" slot="help">
            {#if emailFromParams}
              {l('Your email is from the invite link.')}
            {:else}
              {l('Your email will be used if you forget your password.')}
            {/if}
          </p>
        </TextField>

        <TextField type="password" name="password">
          <span slot="label">{l('Password')}</span>
          <p class="help" slot="help">{l('Hint: Use a phrase from a book.')}</p>
        </TextField>

        <div class="form-actions">
          <Button icon="save" op="{registerOp}"><span>{l(process.env.existing_user ? 'Set new password' : 'Sign up')}</span></Button>
        </div>

        {#if !emailFromParams && !$user.isFirst}
          <p on:click="{scrollspy.scrollTo}">{@html lmd('Go and [sign in](%1) if you already have an account.', '#signin')}</p>
        {/if}

        <OperationStatus op="{registerOp}"/>
      </form>
    {:else}
      <h2>{l('Sign up')}</h2>
      <p>{l('Convos is not open for public registration.')}</p>
      <p on:click="{scrollspy.scrollTo}">{l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
      <div class="form-actions">
        <a class="btn" href="{process.env.contact}">{l('Contact admin')}</a>
      </div>
    {/if}
  </section>

  {#if !$user.isFirst}
    <section id="signin" class="has-max-width">
      <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}">
        <h2>{l('Sign in')}</h2>
        <TextField type="email" name="email" placeholder="{l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
          <span slot="label">{l('E-mail')}</span>
        </TextField>

        <TextField type="password" name="password" autocomplete="current-password">
          <span slot="label">{l('Password')}</span>
        </TextField>

        <div class="form-actions">
          <Button icon="sign-in-alt" op="{loginOp}"><span>{l('Sign in')}</span></Button>
        </div>

        <OperationStatus op="{loginOp}"/>
      </form>
    </section>
  {/if}
</main>

<div class="footer-wrapper">
  <footer class="has-max-width">
    <p>
      Copyright (C) 2012-2020, <a href="https://github.com/nordaaker">Nordaaker</a>.
    </p>
    <p>
      This program is free software, you can redistribute it and/or modify it under
      the terms of the Artistic License version 2.0.
    </p>
    <p>
      <img src="{route.urlFor('/images/convos-light.png')}" alt="" style="height:2.2rem;margin-top:1rem">
    </p>
  </footer>
</div>
