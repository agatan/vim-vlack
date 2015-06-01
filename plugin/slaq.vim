if exists('g:loaded_slaq')
    finish
endif
let g:loaded_slaq = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=1 SlaqOpenChannel :call slaq#open_channel(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
