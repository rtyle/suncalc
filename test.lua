local SunCalc = require "suncalc"

local function near(val1, val2, margin)
    return math.abs(val1 - val2) < (margin or 1E-15)
end

local date = 1362441600
local lat = 50.5
local lng = 30.5
local height = 2000

local testTimes = {
     solarNoon = 1362478257,
     nadir = 1362435057,
     sunrise = 1362458096,
     sunset = 1362498417,
     sunriseEnd = 1362458299,
     sunsetStart = 1362498214,
     dawn = 1362456137,
     dusk = 1362500376,
     nauticalDawn = 1362453871,
     nauticalDusk = 1362502642,
     nightEnd = 1362451577,
     night = 1362504936,
     goldenHourEnd = 1362460741,
     goldenHour = 1362495772
}

local heightTestTimes = {
    solarNoon = 1362478257,
    nadir = 1362435057,
    sunrise = 1362457507,
    sunset = 1362499006
}

local sunPos = SunCalc.getPosition(date, lat, lng)
assert(near(sunPos.azimuth, -2.5003175907168385), 'azimuth')
assert(near(sunPos.altitude, -0.7000406838781611), 'altitude')

for k, v in pairs(SunCalc.getTimes(date, lat, lng)) do
    local V = testTimes[k]
    assert(1 > math.abs(v - V), k)
end

for k, v in pairs(SunCalc.getTimes(date, lat, lng, height)) do
    local V = heightTestTimes[k]
    if nil ~= V then
        assert(1 > math.abs(v - V), k)
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

local moonTimes = SunCalc.getMoonTimes(1362355200, lat, lng, true);
assert(moonTimes.rise, 1362441269)
assert(moonTimes.set, 1362383278)
