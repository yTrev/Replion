--!native
local Signal = require(script.Parent.Parent.Parent.Signal)

local _T = require(script.Parent.Types)

export type Node = {
	children: { [any]: Node }?,
	events: { [string]: Signal.Signal<...any?> }?,
	parent: Node?,
	id: any?,
}

local DESTROYED_ERROR = 'You cannot connect to a destroyed Replion!'

local tree: { n: number, [number]: Node } = { n = 0 }

local function get(value: { [any]: any }?, key: string): any
	if not value or type(value) ~= 'table' then
		return nil
	end

	return value[key]
end

-- using this function insteado of the Utils one to be able to in
local function getPathTable(path: _T.Path): { any }
	if type(path) == 'table' then
		return path
	elseif type(path) == 'string' then
		return string.split(path, '.')
	else
		return { path }
	end
end

local function destroySignal(node: Node, eventName: string)
	if not node.events then
		return
	end

	local signal = node.events[eventName]
	if not signal then
		return
	end

	signal:Destroy()

	node.events[eventName] = nil

	if next(node.events) then
		return
	end

	node.events = nil

	while node.parent do
		local parent = node.parent
		if not node.events and (not node.children or not next(node.children)) then
			assert(parent.children, 'Parent node has no children!')
			parent.children[node.id] = nil
			node = parent
		else
			break
		end
	end
end

function getSignal(node: Node?, eventName: string, path: _T.Path, create: boolean?): Signal.Signal<...any>?
	-- Only create the node/signal if it's really needed
	-- This is to prevent creating a lot of empty tables and unused signals
	local shouldCreate = create == nil or create
	if not node then
		error('You are trying to use a destroyed Replion!')
	end

	for _, index in getPathTable(path) do
		if not node.children or not node.children[index] then
			if shouldCreate then
				local children = node.children or {}
				children[index] = {
					parent = node,
					id = index,
				}

				node.children = children
			else
				return nil
			end
		end

		node = if node.children then node.children[index] else nil

		if not node then
			return nil
		end
	end

	local events = node.events
	if shouldCreate and (not events or not events[eventName]) then
		local newSignal = Signal.new()
		local originalConnect = newSignal.Connect

		newSignal.Connect = function(selfSignal, callback)
			local newConnection = originalConnect(selfSignal, callback)
			local connectionDisconnect = newConnection.Disconnect

			-- To prevent useless memory usage, we can destroy the parents nodes
			-- if there are no more events connected to them
			newConnection.Disconnect = function(selfConnection)
				connectionDisconnect(selfConnection)

				if not (newSignal :: any)._handlerListHead then
					destroySignal(node, eventName)
				end
			end

			newConnection.Destroy = newConnection.Disconnect

			return newConnection
		end

		if not events then
			events = { [eventName] = newSignal }
			node.events = events
		else
			events[eventName] = newSignal
		end
	end

	return if events then events[eventName] else nil
end

function fireEvent(node: Node?, eventName: string, path: _T.Path, ...: any)
	assert(node, DESTROYED_ERROR)

	local signal = getSignal(node, eventName, path, false)
	if signal then
		signal:Fire(...)
	end
end

function connect(node: Node?, eventName: string, path: _T.Path, callback: (...any) -> ())
	assert(node, DESTROYED_ERROR)

	if _G.__DEV__ and not _G.__IGNORE_INSTANCES_WARNING__ then
		-- Warn about the possible memory leak when using Instances as indexes
		local hasInstances = false
		for _, value in getPathTable(path) do
			if typeof(value) ~= 'Instance' then
				continue
			end

			hasInstances = true

			break
		end

		if hasInstances then
			local scriptName, line = debug.info(3, 'sl')

			task.spawn(
				error,
				`[Memory Leak Warning] Instance used as a Connection index at {scriptName}:{line}. `
					.. 'Using Instances will cause memory leaks as Replion cannot automatically '
					.. 'dispose of such connections. Consider using a string or number as your index to prevent this issue.'
			)
		end
	end

	local signal = assert(getSignal(node, eventName, path), 'Signal does not exist!')
	return signal:Connect(callback)
end

local function fireChange(rootNode: Node?, path: _T.Path, newValue: any, oldValue: any)
	assert(rootNode, DESTROYED_ERROR)

	-- we can't process the tree if the root node has no children
	if not rootNode.children then
		return
	end

	local startNode = rootNode
	local startNewValue = newValue
	local startOldValue = oldValue

	if path then
		local pathTable = getPathTable(path)
		local currentNode = startNode
		local currentNewValue = startNewValue
		local currentOldValue = startOldValue

		for i = 1, #pathTable + 1 do
			if currentNode.events and currentNode.events.onChange then
				if currentNewValue ~= currentOldValue then
					currentNode.events.onChange:Fire(currentNewValue, currentOldValue)
				end

				-- update the starting node to the current node
				startNode = currentNode
				startNewValue = currentNewValue
				startOldValue = currentOldValue
			end

			-- navigate deeper if not at the end
			if i <= #pathTable then
				local index = pathTable[i]
				if currentNode.children and currentNode.children[index] then
					currentNode = currentNode.children[index]
					currentNewValue = get(currentNewValue, index)
					currentOldValue = get(currentOldValue, index)
				else
					return -- path doesn't exist, nothing to process
				end
			end
		end
	end

	local head = 1
	local tail = 0
	local nodeQueue = {}
	local newValues = {}
	local oldValues = {}

	if not path then
		tail = 1
		nodeQueue[1] = startNode
		newValues[1] = startNewValue
		oldValues[1] = startOldValue
	else
		-- initialize BFS queue with only the children of startNode
		if not startNode.children or type(startNewValue) ~= 'table' or type(startOldValue) ~= 'table' then
			return
		end

		for key, child in startNode.children do
			local newChildValue = startNewValue[key]
			local oldChildValue = startOldValue[key]
			if newChildValue ~= oldChildValue then
				tail += 1
				nodeQueue[tail] = child
				newValues[tail] = newChildValue
				oldValues[tail] = oldChildValue
			end
		end
	end

	while head <= tail do
		local node = nodeQueue[head]
		local newVal = newValues[head]
		local oldVal = oldValues[head]
		head += 1

		-- fire onChange event if node has one and values are not equal
		if node.events and node.events.onChange then
			node.events.onChange:Fire(newVal, oldVal)
		end

		if node.children and type(newVal) == 'table' and type(oldVal) == 'table' then
			for key, child in node.children do
				local newChildValue = newVal[key]
				local oldChildValue = oldVal[key]
				if newChildValue ~= oldChildValue then
					tail += 1
					nodeQueue[tail] = child
					newValues[tail] = newChildValue
					oldValues[tail] = oldChildValue
				end
			end
		end
	end
end

local function createRootNode(): Node
	tree.n += 1

	local newRootNode: Node = {
		children = {},
	}

	tree[tree.n] = newRootNode

	return newRootNode
end

local function destroyRootNode(rootNode: Node?)
	if not rootNode then
		return
	end

	-- swap the tree with the last one and remove the last one
	local index = table.find(tree, rootNode)
	if not index then
		return
	end

	tree[index] = tree[tree.n]
	tree[tree.n] = nil
	tree.n -= 1

	local queue = { rootNode }
	local front = 1
	local back = 1

	while front <= back do
		local node = queue[front]
		front += 1

		if node.events then
			for _, signal in node.events do
				signal:Destroy()
			end

			node.events = nil
		end

		if node.children then
			for _, child in node.children do
				back += 1
				queue[back] = child
			end
		end

		node.children = nil
		node.parent = nil
	end

	queue = nil
end

return {
	createRootNode = createRootNode,
	destroyRootNode = destroyRootNode,
	getSignal = getSignal,
	fireChange = fireChange,
	fireEvent = fireEvent,
	connect = connect,
}
