scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:slaq_token')
    throw 'Define your token'
endif

if !exists('s:initialized')
    let s:initialized = 1

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
        let g:slaq_name_width = 20
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
    " Null文字を改行に変換するためいったんリストに
    let histories = split(a:history['text'], "\0")
    let len = strlen(a:history['user']['name']) + 2
    let ret = []

    " 一行目用のスペースを作る
    let spaces = ''
    let i = 0
    while i < g:slaq_name_width - len
        let spaces = spaces . ' '
        let i += 1
    endwhile
    call add(ret, '[' . a:history['user']['name'] . ']' . spaces . '| ' . histories[0])

    while strlen(spaces) < g:slaq_name_width
        let spaces .= ' '
    endwhile
    for h in histories[1:]
        call add(ret, spaces . '| ' . h)
    endfor
    return join(ret, "")
endfunction

function! slaq#show_history(channel) abort
    let history = slaq#channel_history(a:channel)
    let bufname = '==Slack: channel(' . a:channel . ')=='
    edit `=bufname`
    silent %d _
    let display_list = map(history, 's:to_show_history(v:val)')
    call setline(1, display_list)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
