-- @Kirosha

local run_service = game:GetService("RunService")

local flag = {}
flag.States = {Up = true, Down = false}
flag.__index = flag

export type CancelFn = () -> ()

export type States = {
	Up: boolean,
	Down: boolean
}

export type Flag = {
	Get: (self: Flag) -> boolean,
	Up: (self: Flag) -> (),
	Down: (self: Flag) -> (),
	Toggle: (self: Flag) -> (),

	Changed: (self: Flag, predicate: (boolean) -> ()) -> CancelFn | nil,
	OnEvent: (self: Flag, event: RBXScriptSignal, state: boolean) -> (),

	WaitUntil: (self: Flag, state: boolean) -> (),
	ExecuteUntil: (self: Flag, state: boolean, predicate: (delta_time: number, ...any) -> (), ...any) -> CancelFn | nil,
	ExecuteAfter: (self: Flag, state: boolean, predicate: (delta_time: number, ...any) -> (), ...any) -> CancelFn | nil,

	Destroy: (self: Flag) -> ()
}

function flag:__update_executors(): ()
	for index, executor in self.__executors do
		if typeof(executor) ~= "table" then continue end

		if self.__current_state == executor.__state then
			table.remove(self.__executors, index)
			coroutine.resume(executor.__thread)
		end
	end

	for _, on_change in self.__on_change do
		task.spawn(on_change, self.__current_state)
	end
end

function flag.new(state: boolean): Flag
	assert(typeof(state) == "boolean", "[FlagUtil]: State must be boolean!")
	return setmetatable({
		__current_state = state,

		__executors = {},
		__on_change = {},
	}, flag)
end

function flag:Up(): ()
	if self.__current_state == flag.States.Up then
		return warn("[FlagUtil]: Flag is already Up!")
	end

	self.__current_state = self.States.Up
	self:__update_executors()
end

function flag:Down(): ()
	if self.__current_state == flag.States.Down then
		return warn("[FlagUtil]: Flag is already Down!")
	end

	self.__current_state = self.States.Down
	self:__update_executors()
end

function flag:Toggle(): ()
	if self.__current_state == self.States.Up then
		self:Down()
	else
		self:Up()
	end
end

function flag:Get(): boolean
	return self.__current_state
end

function flag:OnEvent(event: RBXScriptSignal, state: boolean): ()
	assert(typeof(event) == "RBXScriptSignal", "[FlagUtil]: Event must be RBXScriptSignal!")
	assert(typeof(state) == "boolean", "[FlagUtil]: State must be boolean!")

	if self.__current_state == state then return end

	local connection; connection = event:Once(function()
		table.remove(self.__executors, table.find(self.__executors, connection))
		if self.__current_state == state then return end
		self.__current_state = state
		self:__update_executors()
	end)

	table.insert(self.__executors, connection)
end

function flag:Changed(predicate: (boolean) -> ()): CancelFn | nil
	assert(typeof(predicate) == "function", "[FlagUtil]: Predicate must be function!")
	table.insert(self.__on_change, predicate)
	return function ()
		table.remove(self.__on_change, table.find(self.__on_change, predicate))
	end
end

function flag:WaitUntil(state: boolean): ()
	assert(typeof(state) == "boolean", "[FlagUtil]: State must be boolean!")
	if self.__current_state == state then return end

	local thread = coroutine.running()
	if not thread then return warn("[FlagUtil]: WaitUntil must be called inside a coroutine!") end

	table.insert(self.__executors, {__thread = thread, __state = state})
	return coroutine.yield()
end

function flag:ExecuteUntil(state: boolean, predicate: (number, any) -> (), ...): CancelFn | nil
	assert(typeof(state) == "boolean", "[FlagUtil]: State must be boolean!")
	assert(typeof(predicate) == "function", "[FlagUtil]: Predicate must be function!")
	if self.__current_state == state then return end

	local key = tostring(newproxy())
	local args = { ... }

	local cancel = function()
		return run_service:UnbindFromRenderStep(key)
	end

	run_service:BindToRenderStep(key, Enum.RenderPriority.First.Value + 1, function(delta_time: number)
		if self.__current_state ~= state then
			predicate(delta_time, table.unpack(args))
		else
			cancel()
			table.remove(self.__executors, table.find(self.__executors, cancel))
		end
	end)

	table.insert(self.__executors, cancel)

	return function ()
		cancel()
		table.remove(self.__executors, table.find(self.__executors, cancel))
	end
end

function flag:ExecuteAfter(state: boolean, predicate: (number, any) -> (), ...): CancelFn | nil
	assert(typeof(state) == "boolean", "[FlagUtil]: State must be boolean!")
	assert(typeof(predicate) == "function", "[FlagUtil]: Predicate must be function!")
	if self.__current_state == state then return end

	local args = { ... }

	local cancelled
	local cancel

	local thread = task.spawn(function()
		self:WaitUntil(state)
		if cancelled then return end
		cancel = self:ExecuteUntil(not state, predicate, table.unpack(args))
	end)

	local cache = {__thread = thread, __state = state}

	table.insert(self.__executors, cache)

	return function ()
		cancelled = true
		table.remove(self.__executors, table.find(self.__executors, cache))
		if cancel then
			cancel()
		else
			task.cancel(cache.__thread)
		end
	end
end

function flag:Destroy(): ()
	for _, executor in self.__executors do
		if typeof(executor) == "table" then
			task.cancel(executor.__thread)
		elseif typeof(executor) == "RBXScriptConnection" then
			executor:Disconnect()
		elseif typeof(executor) == "function" then
			executor()
		else
			warn(`[FlagUtil]: Unknown executor type: {typeof(executor)}`)
		end
	end
	self.__executors = {}
	self.__on_change = {}
	setmetatable(self, nil)
end

return flag