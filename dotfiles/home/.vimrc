" 注意：千万不要开启拼写检查，恶心


""" 关于 map 的说明
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" map 以及 remap 是递归的键位映射
" noremap 是非递归的键位映射
" 
" recursive map 和 non-recursive map 的区别：
"   :map j gg           (moves the cursor to the first line)
"   :map Q j            (moves the cursor to the first line)
"   :noremap W j        (moves the cursor down one line)
" Then: 
" - j will be mapped to gg.
" - Q will also be mapped to gg, because j will be expanded for the recursive mapping.
" - W will be mapped to j (and not to gg) because j will not be expanded for the non-recursive mapping.
"
" 还可以对特定模式进行键位映射，如：
" nmap 表示 normal 模式下的键位映射
" nnoremap 表示 normal 模式下的非递归键位映射
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" leader 相关按键
let mapleader=" "

" 可以使用鼠标，a 表示所有模式 (n, v, i, c, a)
set mouse=a

" 显示行号
set number
set showmatch	" Highlight matching brace

" 不要响铃了
" 既不要声音，也不要画面闪烁
set belloff=all
set visualbell

" 自动换行
set nowrap


" 如何进行折叠，manual 表示手动
" set foldmethod=manual

" Highlight all search results
set hlsearch
" Enable smart-case search
set smartcase
" Always case-insensitive
set ignorecase
" Searches for strings incrementally
set incsearch
" Use 'C' style program indenting
set cindent
" Use spaces instead of tabs
set expandtab
" Number of auto-indent spaces
set shiftwidth=4
" Enable smart-indent
set smartindent
" Enable smart-tabs
set smarttab
" Show row and column ruler information
set ruler
" Number of undo levels
set undolevels=1000
" set UTF-8 encoding
set enc=utf-8
set fenc=utf-8
set termencoding=utf-8

" disable vi compatibility (emulation of old bugs)
set nocompatible
" configure tabwidth and insert spaces instead of tabs
set tabstop=4        " tab width is 4 spaces
" turn syntax highlighting on
set t_Co=256
syntax on


" 前一行/后一行
nnoremap J <C-e><C-e>
nnoremap K <C-y><C-y>

" bf 是翻一页；ud 是翻半页
nnoremap H <C-u>zz
nnoremap L <C-d>zz

" 取消搜索的高亮
nnoremap qh :noh<CR>

" 保存
nnoremap <leader>ww :w<CR>
" redo 
nnoremap U :redo<CR>


" 翻页居中
" j 表示物理行；gj 表示屏幕行
" noremap j gjzz
" noremap k gkzz
" noremap n nzz
" noremap <s-n> <s-n>zz
" noremap * *zz
" noremap # #zz
set scrolloff=4

" 使用 jk 替代 esc
" imap jk <Esc>
