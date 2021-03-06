<script>
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import {closestEl, q, regexpEscape, tagNameIs} from '../js/util';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {route} from '../store/Route';

export let transition;

const user = getContext('user');
const notifications = $user.notifications;

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchHasFocus = false;
let visibleLinks = [];

$: filterNav({filter, type: 'change'}); // Passing "filter" in to make sure filterNav() is called on change
$: searchQuery = filter.replace(/^\//, '');
$: if (navEl) clearFilter($route);
$: if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.add('has-focus');

function clearFilter() {
  searchHasFocus = false;
  q(navEl, 'a', aEl => aEl.classList.remove('has-focus'));

  setTimeout(() => {
    if (!navEl) return;
    filter = '';
    const el = document.activeElement;
    if (el && closestEl(el, navEl)) q(navEl, 'a.has-path', aEl => aEl.focus());
  }, 100);
}

function dialogClassNames(connection, dialog) {
  const cn = [dialog.dialog_id ? 'for-dialog' : 'for-connection'];
  if (dialog.frozen || connection.state != 'connected') cn.push('is-frozen');
  if (dialog.errors) cn.push('has-errors');
  return cn.join(' ');
}

function filterNav() {
  if (!navEl) return;

  activeLinkIndex = 0;
  searchHasFocus = true;
  visibleLinks = [];

  const prefix = [filter.match(/^\W+/) ? '' : '\\b\\W*'];
  if (prefix[0]) prefix.push('');

  // Show and hide navigation links
  for (let p = 0; p < prefix.length; p++) {
    const filterRe = new RegExp(prefix[p] + regexpEscape(filter), 'i');
    const seen = {};
    q(navEl, 'a', (aEl, i) => {
      const aClassList = aEl.classList;
      if (!filter.length && aClassList.contains('has-path')) activeLinkIndex = i;
      aClassList.remove('has-focus');

      const makeVisible = !filter.length || (!aEl.href.match(/\/search$/) && !seen[aEl.href] && aEl.textContent.match(filterRe));
      if (makeVisible) visibleLinks.push(aEl);
      aEl.classList[makeVisible ? 'remove' : 'add']('hidden');
      seen[aEl.href] = true;
    });

    if (visibleLinks.length) break;
  }

  // Show connections
  q(navEl, '.for-connection', connEl => {
    let el = connEl;
    while ((el = el.nextElementSibling)) {
      if (!el.classList.contains('for-dialog')) break;
      if (!el.classList.contains('hidden')) return connEl.classList.remove('hidden');
    }
  });

  // Allow search in chat history
  const searchEl = navEl.querySelector('.for-search');
  searchEl.classList[filter ? 'remove' : 'add']('hidden');
  if (!searchEl.classList.contains('hidden')) visibleLinks.push(searchEl);

  // Show headings
  q(navEl, 'h3', h3 => {
    let el = h3;
    while ((el = el.nextElementSibling)) {
      if (tagNameIs(el, 'h3')) break;
      if (!el.classList.contains('hidden')) return h3.classList.remove('hidden');
    }

    h3.classList.add('hidden');
  });
}

function onNavItemClicked(e) {
  const iconName = (e.target.className || '').match(/(network|user)/);
  if (iconName) setTimeout(() => route.update({activeMenu: 'settings'}), 50);
}

function onSearchKeydown(e) {
  // Go to the active link when Enter is pressed
  if (e.keyCode == 13) {
    e.preventDefault();
    clearFilter();
    if (visibleLinks[activeLinkIndex]) route.go(visibleLinks[activeLinkIndex].href);
    return;
  }

  // Move focus from/to a given navigation link
  // TODO: Add support for j/k, with some sort of additional combination
  // Currently only Up/Down array keys will update the focused link
  const moveBy = e.keyCode == 38 ? -1 : e.keyCode == 40 ? 1 : 0;
  if (moveBy) {
    e.preventDefault();
    if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.remove('has-focus');
    activeLinkIndex += e.ctrlKey ? moveBy * 4 : moveBy;
  }

  // Make sure we do not try to focus a link that is not visible
  if (activeLinkIndex < 0) activeLinkIndex = visibleLinks.length - 1;
  if (activeLinkIndex >= visibleLinks.length) activeLinkIndex = 0;
}

function renderUnread(dialog) {
  return dialog.unread > 60 ? '60+' : dialog.unread || 0;
}
</script>

<div class="sidebar-left" transition:fly="{transition}">
  <form class="sidebar__header has-tooltip is-below" data-tooltip="{l('Search for conversations or messages')}" on:submit="{e => e.preventDefault()}">
    <input type="text" id="search_input"
      placeholder="{searchHasFocus ? l('Search...') : l('Convos')}"
      bind:value="{filter}"
      on:blur="{clearFilter}"
      on:focus="{filterNav}"
      on:keydown="{onSearchKeydown}">
    <label for="search_input"><Icon name="search"/></label>
  </form>

  <nav class="sidebar-left__nav" class:is-filtering="{filter.length > 0}" bind:this="{navEl}" on:click="{onNavItemClicked}">
    <h3>{l('Conversations')}</h3>
    {#if !$user.connections.size}
      <Link href="/settings/connection">
        <Icon name="exclamation-circle"/>
        <span>{l('No conversations')}</span>
      </Link>
    {/if}
    {#each $user.connections.toArray() as connection}
      <Link href="{connection.path}" class="{dialogClassNames(connection, connection)}">
        <Icon name="network-wired"/>
        <span>{connection.name || connection.connection_id}</span>
        <b class="unread" hidden="{!connection.unread}">{renderUnread(connection)}</b>
      </Link>
      {#each connection.dialogs.toArray() as dialog}
        <Link href="{dialog.path}" class="{dialogClassNames(connection, dialog)}">
          <Icon name="{dialog.is_private ? 'user' : 'user-friends'}"/>
          <span>{dialog.name}</span>
          <b class="unread" hidden="{!dialog.unread}">{renderUnread(dialog)}</b>
        </Link>
      {/each}
    {/each}

    <h3>{$user.email || l('Account')}</h3>
    <Link href="/chat">
      <Icon name="{$notifications.unread ? 'bell' : 'bell-slash'}"/>
      <span>{l('Notifications')}</span>
      <b class="unread" hidden="{!$notifications.unread}">{renderUnread($notifications)}</b>
    </Link>
    <Link href="/search">
      <Icon name="search"/>
      <span>{l('Search')}</span>
    </Link>
    <Link href="/settings/conversation">
      <Icon name="comment"/>
      <span>{l('Add conversation')}</span>
    </Link>
    <Link href="/settings/connection">
      <Icon name="network-wired"/>
      <span>{l('Add connection')}</span>
    </Link>
    <Link href="/settings/account">
      <Icon name="user-cog"/>
      <span>{l('Account')}</span>
    </Link>
    <Link href="/help">
      <Icon name="question-circle"/>
      <span>{l('Help')}</span>
    </Link>
    {#if $user.is('admin')}
      <Link href="/settings">
        <Icon name="tools"/>
        <span>{l('Settings')}</span>
      </Link>
      <Link href="/settings/users">
        <Icon name="users"/>
        <span>{l('Users')}</span>
      </Link>
    {/if}
    <a href="{route.urlFor('/logout')}" target="_self">
      <Icon name="power-off"/>
      <span>{l('Log out')}</span>
    </a>
    <Link href="/search?q={encodeURIComponent(searchQuery)}" class="for-search hidden">
      <Icon name="search"/>
      <span>{l('Search for "%1"', searchQuery)}</span>
    </Link>
  </nav>
</div>
