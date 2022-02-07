"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[438],{84041:function(e){e.exports=JSON.parse('{"functions":[{"name":"Start","desc":"Starts the ReplionController. This should be called once.","params":[],"returns":[],"function_type":"static","source":{"line":229,"path":"src/ReplionController/init.lua"}},{"name":"OnStart","desc":"","params":[],"returns":[{"desc":"","lua_type":"Promise"}],"function_type":"static","source":{"line":271,"path":"src/ReplionController/init.lua"}},{"name":"OnReplionAdded","desc":"A callback that is called when a replion is created.","params":[{"name":"callback","desc":"","lua_type":"EventCallback"}],"returns":[{"desc":"","lua_type":"Connection"}],"function_type":"method","source":{"line":284,"path":"src/ReplionController/init.lua"}},{"name":"OnReplionAddedWithTag","desc":"A callback that will be called when a replion that contains the given tag is created.","params":[{"name":"tag","desc":"","lua_type":"string"},{"name":"callback","desc":"","lua_type":"EventCallback"}],"returns":[{"desc":"","lua_type":"Connection"}],"function_type":"method","source":{"line":297,"path":"src/ReplionController/init.lua"}},{"name":"OnReplionRemoved","desc":"A callback that is called when a replion is removed.","params":[{"name":"callback","desc":"","lua_type":"EventCallback"}],"returns":[{"desc":"","lua_type":"Connection"}],"function_type":"method","source":{"line":313,"path":"src/ReplionController/init.lua"}},{"name":"OnReplionRemovedWithTag","desc":"A callback that will be called when a replion that contains the given tag is removed.","params":[{"name":"tag","desc":"","lua_type":"string"},{"name":"callback","desc":"","lua_type":"EventCallback"}],"returns":[{"desc":"","lua_type":"Connection"}],"function_type":"method","source":{"line":325,"path":"src/ReplionController/init.lua"}},{"name":"AwaitReplion","desc":"About Promises: https://eryn.io/roblox-lua-promise/api/Promise/","params":[{"name":"name","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Promise"}],"function_type":"method","source":{"line":341,"path":"src/ReplionController/init.lua"}},{"name":"WaitReplion","desc":"Alias for `ReplionController:AwaitReplion(name):expect()`","params":[{"name":"name","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"ClientReplion"}],"function_type":"method","yields":true,"source":{"line":362,"path":"src/ReplionController/init.lua"}},{"name":"GetReplion","desc":"","params":[{"name":"name","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"ClientReplion?"}],"function_type":"method","source":{"line":369,"path":"src/ReplionController/init.lua"}}],"properties":[{"name":"Action","desc":"","lua_type":"Enums","tags":["Enum"],"readonly":true,"source":{"line":211,"path":"src/ReplionController/init.lua"}},{"name":"ClientReplion","desc":"","lua_type":"ClientReplion","readonly":true,"source":{"line":217,"path":"src/ReplionController/init.lua"}}],"types":[{"name":"EventCallback","desc":"","lua_type":"(name: string, replion: ClientReplion) -> ()","source":{"line":204,"path":"src/ReplionController/init.lua"}}],"name":"ReplionController","desc":"","realm":["Client"],"source":{"line":222,"path":"src/ReplionController/init.lua"}}')}}]);