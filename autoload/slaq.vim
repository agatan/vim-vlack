scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! s:get(api_name, arg) abort
    let a:arg['token'] = g:slaq_token
    return s:H.get('https://slack.com/api/' . a:api_name, a:arg).content
endfunction

function! s:post(api_name, arg) abort
    let a:arg['token'] = g:slaq_token
    return s:H.post('https://slack.com/api/' . a:api_name, a:arg).content
endfunction

function! s:init() abort
    if exists('s:initialized')
        return
    endif
    let s:initialized = 0

    if !exists('g:slaq_token')
        throw 'Define your token'
    endif

    if !exists('g:slaq_initialized')
        let g:slaq_initialized = 1
        let s:V = vital#of('slaq')
        let s:H = s:V.import('Web.HTTP')
        let s:J = s:V.import('Web.JSON')
        let s:channles = {}
        let res = s:J.decode(s:get('channels.list', {}))
        if !res.ok
            throw 'cannot get channels list'
        endif
        for c in res.channels
            let s:channles[c.name] = c
        endfor

        let s:users = {}
        let res = s:J.decode(s:get('users.list', {}))
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
endfunction


function! s:channel_history(channel, ...) abort
    if !has_key(s:channles, a:channel)
        throw 'No such channel'
    endif
    let option = get(a:, 1, {})
    let option['channel'] = s:channles[a:channel].id
    let res = s:J.decode(s:get('channels.history', option))
    if !res.ok
        throw 'cannot get history'
    endif
    for message in res.messages
        if has_key(message, 'user')
            let message['user'] = has_key(s:users, message['user']) ? s:users[message['user']] : ''
        else
            let message['user'] = {'name': ''}
        endif
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
    call s:init()
    let history = s:channel_history(a:channel)
    let bufname = '==Slack: channel(' . a:channel . ')=='
    edit `=bufname`
    let b:channel_name = a:channel
    let b:history = copy(history)
    setlocal buftype=nowrite
    setlocal noswapfile
    setlocal bufhidden=wipe
    setlocal nonumber
    setlocal modifiable
    silent %d _
    let display_list = map(history, 's:to_show_history(v:val)')
    call setline(1, display_list)
    setlocal nomodifiable
    nnoremap <buffer> r :call slaq#reload_channel()<CR>
    nnoremap <buffer> i :call slaq#post_to_channel_buffer()<CR>
endfunction

function! slaq#reload_channel() abort
    if !exists('b:channel_name') || !exists('b:history')
        return
    endif
    let latest = b:history[0].ts
    let history = s:channel_history(b:channel_name, { 'oldest': latest })
    let display_list = map(copy(history), 's:to_show_history(v:val)')
    setlocal modifiable
    for i in range(0, len(history) - 1)
        call append(i,display_list[i])
        call insert(b:history, history[i], i)
    endfor
    setlocal nomodifiable
endfunction

function! slaq#post_to_channel_buffer() abort
    if !exists('b:channel_name') || !exists('b:history')
        return
    endif
    if !has_key(s:channles, b:channel_name)
        return
    endif
    let channel_name = b:channel_name
    let channel_id = s:channles[b:channel_name].id
    3new `='Slack: post('.b:channel_name`
    silent %d _
    setlocal buftype=nowrite
    setlocal noswapfile
    setlocal nonumber
    setlocal bufhidden=wipe
    nnoremap <CR> :<C-u>call slaq#post_to_channel()<CR>
    let b:channel_id = channel_id
    let b:channel_name = channel_name
endfunction

function! slaq#post_to_channel() abort
    if !exists('b:channel_id') || !exists('b:channel_name')
        return
    endif
    let msg = getline('.')
    if msg ==# ''
        return
    endif
    let res = s:J.decode(s:post('chat.postMessage', {'channel': b:channel_id, 'text': msg, 'as_user': 'true'}))
    if !res.ok
        echo 'could not post message'
        echo res
        return
    endif
    let post_buf_id = bufnr('%')
    let history_buf_id = bufnr('==Slack: channel(' . b:channel_name . ')==')
    if history_buf_id == -1
        return
    endif
    execute history_buf_id . 'buffer'
    call slaq#reload_channel()
    quit
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
