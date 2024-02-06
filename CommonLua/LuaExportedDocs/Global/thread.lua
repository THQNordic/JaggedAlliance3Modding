-- @cstyle thread CreateRealTimeThread(function exec)
function CreateRealTimeThread(exec, ...)
end

-- @cstyle thread CreateGameTimeThread(function exec)
function CreateGameTimeThread(exec, ...)
end

-- @cstyle thread CreateMapRealTimeThread(function exec)
function CreateMapRealTimeThread(exec, ...)
end

-- @cstyle thread IsRealTimeThread(thread thread)
function IsRealTimeThread(thread)
end

-- @cstyle thread IsGameTimeThread(thread thread)
function IsGameTimeThread(thread)
end

-- @cstyle int RealTime()
-- @return int, Current real time in ms
function RealTime()
end

-- @cstyle int GameTime()
-- @return int, Current game time in ms
function GameTime()
end

-- @cstyle int now()
-- @return int, Current time, depending on the current thread type, in ms
function now()
end

-- @cstyle thread CurrentThread()
function CurrentThread()
end

-- @cstyle bool IsValidThread(thread thread)
-- @return bool, True if the given thread is alive
function IsValidThread(thread)
end

-- @cstyle string GetThreadStatus(thread thread)
function GetThreadStatus(thread)
end

-- @cstyle bool CanYield()
function CanYield()
end

-- @cstyle void Sleep(int time)
-- @param time int, Time to sleep in ms.
function Sleep(time)
end

-- @cstyle void InterruptAdvance()
function InterruptAdvance()
end

-- @cstyle void DeleteThread(thread thread, bool allow_if_current)
function DeleteThread(thread, allow_if_current)
end

-- Wait the current thread to be woken up with Wakeup
-- @cstyle bool WaitWakeup(int timeout)
-- @param timeout int, Time to wait in ms.
-- @return bool, True if awaken before the time expires
function WaitWakeup(timeout)
end

-- Wakes up a thread put to sleep with WaitWakeup
-- @cstyle void Wakeup(thread thread, ...)
function Wakeup(thread, ...)
end

-- Wait for a specific message to be fired
-- @cstyle template<class T> bool WaitMsg(T msg, int timeout)
-- @return bool, True if message has been fired before the time expires
function WaitMsg(msg, timeout)
end