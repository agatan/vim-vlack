scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:slaq_token')
    throw 'Define your token'
endif

if !exists('g:slaq_initialized')
    let g:slaq_initialized = 1
    let s:V = vital#of('slaq')
    let s:H = s:V.import('Web.HTTP')
    let s:J = s:V.import('Web.JSON')
    let s:channles = {}
    let res = s:J.decode(slaq#get('channels.list', {}))
    if !res.ok
        throw 'cannot get channels list'
    endif
    for c in res.channels
        let s:channles[c.name] = c
    endfor

    let s:users = {}
    let res = s:J.decode(slaq#get('users.list', {}))
    if !res.ok
        throw 'cannot get users list'
    endif
    for u in res.members
        let s:users[u.id] = u
    endfor

    if !exists('g:slaq_name_width')
        let g:slaq_name_width = 10
    endif
endif

function! slaq#get(api_name, arg) abort
    let a:arg['token'] = g:slaq_token
    return s:H.get('https://slack.com/api/' . a:api_name, a:arg).content
endfunction

function! slaq#channel_history(channel) abort
    if !has_key(s:channles, a:channel)
        throw 'No such channel'
    endif
    let res = s:J.decode(slaq#get('channels.history', {'channel': s:channles[a:channel].id}))
    if !res.ok
        throw 'cannot get history'
    endif
    for message in res.messages
        let message['user'] = has_key(s:users, message['user']) ? s:users[message['user']] : ''
    endfor
    return res.messages
endfunction

function! s:to_show_history(history) abort
    let len = strlen(a:history['user']['name'])

    let spaces = ''
    let i = 0
    while i < g:slaq_name_width - len
        let spaces = spaces . ' '
        let i += 1
    endwhile
    return a:history['user']['name'] . spaces . '| ' . s:replace_name(a:history['text'])
endfunction

function! s:replace_name(message) abort
    let name = matchlist(a:message, '^<@\(.\+\)>', 0)
    if empty(name)
        return a:message
    endif
    if !has_key(s:users, name[1])
        return a:message
    endif
    return substitute(a:message, '^<@.\+>', '@' . s:users[name[1]]['name'], '')
endfunction

function! slaq#open_channel(channel) abort
    let history = slaq#channel_history(a:channel)
    let bufname = '==Slack: channel(' . a:channel . ')=='
    edit `=bufname`
    setlocal buftype=nowrite
    setlocal noswapfile
    setlocal bufhidden=wipe
    setlocal nonumber
    setlocal readonly
    setlocal nomodifiable
    silent %d _
    let display_list = map(history, 's:to_show_history(v:val)')
    call setline(1, display_list)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
