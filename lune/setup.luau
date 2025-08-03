local process = require('@lune/process')
local fs = require('@lune/fs')
local task = require('@lune/task')

process.exec('wally', { 'install' }, { stdio = 'forward' })

if fs.isFile('sourcemap.json') then
	fs.removeFile('sourcemap.json')
end

-- simple workaround for generating a UTF-8 sourcemap (shell mode outputs UTF-16 LE)
local sourcemap = process.create('rojo', { 'sourcemap', 'test.project.json', '--watch', '-o', 'sourcemap.json' })

repeat
	task.wait()
until fs.isFile('sourcemap.json')

process.exec('wally-package-types', { '--sourcemap', 'sourcemap.json', 'Packages' }, { stdio = 'forward' })
sourcemap:kill()
