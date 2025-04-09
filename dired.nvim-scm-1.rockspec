rockspec_format = '3.0'
package = 'dired.nvim'
version = 'scm-1'

test_dependencies = {
  'lua >= 5.1',
  'nlua',
}

source = {
  url = 'git://github.com/xiaoshihou514/' .. package,
}

build = {
  type = 'builtin',
}
