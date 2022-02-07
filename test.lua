-- we must be able to translate unix_time
-- into an ISO 8601 formatted specification
-- this is easy in native lua as long as we are in the GMT timezone
-- which we insist:
assert(os.getenv("TZ") == "0", "must run with TZ=0 in environment")
local function to_iso_time(unix_time)
    return os.date("%FT%TZ", math.floor(unix_time))
end

local SunCalc = require "suncalc"


local function near(val1, val2, margin)
    return math.abs(val1 - val2) < (margin or 1E-15)
end

local date = 1362441600 -- date --date=2013-03-05Z +%s
local lat = 50.5
local lng = 30.5
local height = 2000

local testTimes = {
    solarNoon = '2013-03-05T10:10:57Z',
    nadir = '2013-03-04T22:10:57Z',
    sunrise = '2013-03-05T04:34:56Z',
    sunset = '2013-03-05T15:46:57Z',
    sunriseEnd = '2013-03-05T04:38:19Z',
    sunsetStart = '2013-03-05T15:43:34Z',
    dawn = '2013-03-05T04:02:17Z',
    dusk = '2013-03-05T16:19:36Z',
    nauticalDawn = '2013-03-05T03:24:31Z',
    nauticalDusk = '2013-03-05T16:57:22Z',
    nightEnd = '2013-03-05T02:46:17Z',
    night = '2013-03-05T17:35:36Z',
    goldenHourEnd = '2013-03-05T05:19:01Z',
    goldenHour = '2013-03-05T15:02:52Z'
}

local heightTestTimes = {
    solarNoon = '2013-03-05T10:10:57Z',
    nadir = '2013-03-04T22:10:57Z',
    sunrise = '2013-03-05T04:25:07Z',
    sunset = '2013-03-05T15:56:46Z'
}


local sunPos = SunCalc.getPosition(date, lat, lng)

assert(near(sunPos.azimuth, -2.5003175907168385), 'azimuth')
assert(near(sunPos.altitude, -0.7000406838781611), 'altitude')




for k, v in pairs(SunCalc.getTimes(date, lat, lng)) do


    assert(to_iso_time(v) == testTimes[k], k)


end


for k, v in pairs(SunCalc.getTimes(date, lat, lng, height)) do
    local iso_time = heightTestTimes[k]
    if nil ~= iso_time then
        assert(to_iso_time(v) == iso_time, k)
    end

end


local moonPos = SunCalc.getMoonPosition(date, lat, lng)

assert(near(moonPos.azimuth, -0.9783999522438226), 'azimuth')
assert(near(moonPos.altitude, 0.014551482243892251), 'altitude')
assert(near(moonPos.distance, 364121.37256256194), 'distance')




local moonIllum = SunCalc.getMoonIllumination(date)

assert(near(moonIllum.fraction, 0.4848068202456373), 'fraction')
assert(near(moonIllum.phase, 0.7548368838538762), 'phase')
assert(near(moonIllum.angle, 1.6732942678578346), 'angle')




local moonTimes = SunCalc.getMoonTimes(1362355200, lat, lng, true); -- date --date=2013-03-04Z +%s

assert(to_iso_time(moonTimes.rise), "2013-03-04T23:54:29Z")
assert(to_iso_time(moonTimes.set), "2013-03-04T07:47:58Z")
