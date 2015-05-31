if exists('g:loaded_slaq')
    finish
endif
let g:loaded_slaq = 1

let s:save_cpo = &cpo
set cpo&vim

command! Test call slaq#test()

let &cpo = s:save_cpo
unlet s:save_cpo
