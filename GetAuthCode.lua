local ip_block_time=15 --封禁IP时间（秒）
local ip_time_out=10    --指定ip访问频率时间段（秒）
local ip_max_count=80 --指定ip访问频率计数最大值（秒）
local BUSINESS = ngx.var.business
local redis = require "resty.redis"
local conn = redis:new()
ok, err = conn:connect("172.31.40.172", 6379)
conn:set_timeout(2000)
--放行白名单
--myIP = ngx.req.get_headers()["X-Real-IP"]
--if myIP == nil then
--   myIP = ngx.req.get_headers()["x_forwarded_for"]
--end
--if myIP == nil then
--   myIP = ngx.var.remote_addr
--end
--local hasIP = red:sismember('bai.ip',myIP)
--if hasIP==1 then
-- goto FLAG
-- ngx.say(hasIP)
--end


--如果连接失败，跳转到脚本结尾
if not ok then
    goto FLAG
end

clIP = ngx.req.get_headers()["X-Real-IP"]
if clIP == nil then
    goto FLAG
end
myIP = ngx.req.get_headers()["X-Real-IP"]
if myIP == nil then
   myIP = ngx.req.get_headers()["x_forwarded_for"]
end
if myIP == nil then
   myIP = ngx.var.remote_addr
end
hasIP = conn:sismember('bai.ip',myIP)
if hasIP==1 then
   goto FLAG
end
is_block, err = conn:get(BUSINESS.."-BLOCK-"..ngx.req.get_headers()["X-Real-IP"])
if is_block == '1' then
    ngx.exit(403)
    goto FLAG
end
ip_count, err = conn:get(BUSINESS.."-COUNT-"..ngx.req.get_headers()["X-Real-IP"])

if ip_count == ngx.null then --如果不存在，则将该IP存入redis，并将计数器设置为1、该KEY的超时时间为ip_time_out
    res, err = conn:set(BUSINESS.."-COUNT-"..ngx.req.get_headers()["X-Real-IP"], 1)
        res, err = conn:expire(BUSINESS.."-COUNT-"..ngx.req.get_headers()["X-Real-IP"], ip_time_out)
else
    ip_count = ip_count + 1 --存在则将单位时间内的访问次数加1

    if ip_count >= ip_max_count then --如果超过单位时间限制的访问次数，则添加限制访问标识，限制时间为ip_block_time
        res, err = conn:set(BUSINESS.."-BLOCK-"..ngx.req.get_headers()["X-Real-IP"], 1)
        res, err = conn:expire(BUSINESS.."-BLOCK-"..ngx.req.get_headers()["X-Real-IP"], ip_block_time)
        else
        res, err = conn:set(BUSINESS.."-COUNT-"..ngx.req.get_headers()["X-Real-IP"],ip_count)
                res, err = conn:expire(BUSINESS.."-COUNT-"..ngx.req.get_headers()["X-Real-IP"], ip_time_out)
    end
end
-- 结束标记
::FLAG::
local ok, err = conn:close()
