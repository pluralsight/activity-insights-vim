## How to Install
1. Install the vim plugin (find your plugin manager of choice below)
2. In vim run `:PluralsightRegister`

#### Vim 8+ packages

If you are using VIM version 8 or higher you can use its built-in package management; see `:help packages` for more information. Just run these commands in your terminal:

```bash
git clone https://github.com/pluralsight/activity-insights-vim ~/.vim/pack/pluralsight/start/ps-activity-insights
```

Otherwise, these are some of the several 3rd-party plugin managers you can choose from. Be sure you read the instructions for your chosen plugin, as there typically are additional steps you need to take.

#### [pathogen.vim](https://github.com/tpope/vim-pathogen)

In the terminal,
```bash
git clone https://github.com/pluralsight/activity-insights-vim.git ~/.vim/bundle/ps-activity-insights
```
In your vimrc,
```vim
call pathogen#infect()
syntax on
filetype plugin indent on
```

#### [Vundle.vim](https://github.com/VundleVim/Vundle.vim)
```vim
call vundle#begin()
Plugin 'pluralsight/activity-insights-vim'
call vundle#end()
```

#### [vim-plug](https://github.com/junegunn/vim-plug)
```vim
call plug#begin()
Plug 'pluralsight/activity-insights-vim'
call plug#end()
```

#### [dein.vim](https://github.com/Shougo/dein.vim)
```vim
call dein#begin()
call dein#add('pluralsight/activity-insights-vim')
call dein#end()
```

#### [apt-vim](https://github.com/egalpin/apt-vim)
```bash
apt-vim install -y https://github.com/pluralsight/activity-insights-vim.git
```
