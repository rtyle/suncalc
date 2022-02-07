--[[
SunCalc is a lua library for calculating sun/moon position and light phases.

This is a mechanical/manual lua translation from original javascript source
https://github.com/mourner/suncalc
from commit 031c4ad3f6f330a02863ec0f43b820115294ccca

Thank you!

The lua translation was performed so as to make a diff from the original javascript meaningful.
That is, the only differences should be the mechanical lua translation.
This should make it easier to track changes in the original javascript source.

Honorable mention is due to
https://github.com/woodsnake/lua-suncalc
which, apparently, is a previous translation
but, unfortunately, lacks some later capabilities.
]]--

-- for simple translation of javascript ternary comparison operator ?:
local function ternary(a, b, c) if a then return b end return c end

-- shortcuts for easier to read formulas

local PI = math.pi
local sin = math.sin
local cos = math.cos
local tan = math.tan
local asin = math.asin
local atan = math.atan
local acos = math.acos
local rad = PI / 180

-- sun calculations are based on http://aa.quae.nl/en/reken/zonpositie.html formulas


--  date/time constants and conversions

local dayS = 60 * 60 * 24
local J1970 = 2440588
local J2000 = 2451545

local function toJulian(date) return date / dayS - 0.5 + J1970 end
local function fromJulian(j)  return (j + 0.5 - J1970) * dayS end
local function toDays(date)   return toJulian(date) - J2000 end


-- general calculations for position

local e = rad * 23.4397 -- obliquity of the Earth

local function rightAscension(l, b) return atan(sin(l) * cos(e) - tan(b) * sin(e), cos(l)) end
local function declination(l, b)    return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l)) end

local function azimuth(H, phi, dec)  return atan(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi)) end
local function altitude(H, phi, dec) return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H)) end

local function siderealTime(d, lw) return rad * (280.16 + 360.9856235 * d) - lw end

local function astroRefraction(h)
    if (h < 0) then -- the following formula works for positive altitudes only.
        h = 0 end   -- if h = -0.08901179 a div/0 would occur.

    -- formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    -- 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    return 0.0002967 / math.tan(h + 0.00312536 / (h + 0.08901179))
end

-- general sun calculations

local function solarMeanAnomaly(d) return rad * (357.5291 + 0.98560028 * d) end

local function eclipticLongitude(M)

    local C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M)) -- equation of center
    local P = rad * 102.9372 -- perihelion of the Earth

    return M + C + P + PI
end

local function sunCoords(d)

    local M = solarMeanAnomaly(d)
    local L = eclipticLongitude(M)

    return {
        dec = declination(L, 0),
        ra = rightAscension(L, 0)
    }
end


local SunCalc = {}


-- calculates sun position for a given date and latitude/longitude

SunCalc.getPosition = function (date, lat, lng)

    local lw  = rad * -lng
    local phi = rad * lat
    local d   = toDays(date)

    local c  = sunCoords(d)
    local H  = siderealTime(d, lw) - c.ra

    return {
        azimuth = azimuth(H, phi, c.dec),
        altitude = altitude(H, phi, c.dec)
    }
end


-- sun times configuration (angle, morning name, evening name)

SunCalc.times = {
    {-0.833, 'sunrise',       'sunset'      },
    {  -0.3, 'sunriseEnd',    'sunsetStart' },
    {    -6, 'dawn',          'dusk'        },
    {   -12, 'nauticalDawn',  'nauticalDusk'},
    {   -18, 'nightEnd',      'night'       },
    {     6, 'goldenHourEnd', 'goldenHour'  }
}

-- adds a custom time to the times config

SunCalc.addTime = function (angle, riseName, setName)
    table.insert(SunCalc.times, {angle, riseName, setName})
end


-- calculations for sun times

local J0 = 0.0009

local function julianCycle(d, lw) return math.floor(0.5 + (d - J0 - lw / (2 * PI))) end

local function approxTransit(Ht, lw, n) return J0 + (Ht + lw) / (2 * PI) + n end
local function solarTransitJ(ds, M, L)  return J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L) end

local function hourAngle(h, phi, d) return acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d))) end
local function observerAngle(height) return -2.076 * math.sqrt(height) / 60 end

-- returns set time for the given sun altitude
local function getSetJ(h, lw, phi, dec, n, M, L)

    local w = hourAngle(h, phi, dec)
    local a = approxTransit(w, lw, n)
    return solarTransitJ(a, M, L)
end


-- calculates sun times for a given date, latitude/longitude, and, optionally,
-- the observer height (in meters) relative to the horizon

SunCalc.getTimes = function (date, lat, lng, height)

    height = height or 0

    local lw = rad * -lng
    local phi = rad * lat

    local dh = observerAngle(height)

    local d = toDays(date)
    local n = julianCycle(d, lw)
    local ds = approxTransit(0, lw, n)

    local M = solarMeanAnomaly(ds)
    local L = eclipticLongitude(M)
    local dec = declination(L, 0)

    local Jnoon = solarTransitJ(ds, M, L)

    local h0, Jset, Jrise


    local result = {
        solarNoon = fromJulian(Jnoon),
        nadir = fromJulian(Jnoon - 0.5)
    }

    for _, time in ipairs(SunCalc.times) do

        h0 = (time[01] + dh) * rad

        Jset = getSetJ(h0, lw, phi, dec, n, M, L)
        Jrise = Jnoon - (Jset - Jnoon)

        result[time[2]] = fromJulian(Jrise)
        result[time[3]] = fromJulian(Jset)
    end

    return result
end


-- moon calculations, based on http://aa.quae.nl/en/reken/hemelpositie.html formulas

local function moonCoords(d) -- geocentric ecliptic coordinates of the moon

    local L = rad * (218.316 + 13.176396 * d) -- ecliptic longitude
    local M = rad * (134.963 + 13.064993 * d) -- mean anomaly
    local F = rad * (93.272 + 13.229350 * d)  -- mean distance

    local l  = L + rad * 6.289 * sin(M) -- longitude
    local b  = rad * 5.128 * sin(F)     -- latitude
    local dt = 385001 - 20905 * cos(M)  -- distance to the moon in km

    return {
        ra = rightAscension(l, b),
        dec = declination(l, b),
        dist = dt
    }
end

SunCalc.getMoonPosition = function (date, lat, lng)

    local lw  = rad * -lng
    local phi = rad * lat
    local d   = toDays(date)

    local c = moonCoords(d)
    local H = siderealTime(d, lw) - c.ra
    local h = altitude(H, phi, c.dec)
    -- formula 14.1 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    local pa = atan(sin(H), tan(phi) * cos(c.dec) - sin(c.dec) * cos(H))

    h = h + astroRefraction(h) -- altitude correction for refraction

    return {
        azimuth = azimuth(H, phi, c.dec),
        altitude = h,
        distance = c.dist,
        parallacticAngle = pa
    }
end


-- calculations for illumination parameters of the moon,
-- based on http://idlastro.gsfc.nasa.gov/ftp/pro/astro/mphase.pro formulas and
-- Chapter 48 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.

SunCalc.getMoonIllumination = function (date)

    local d = toDays(date or os.time())
    local s = sunCoords(d)
    local m = moonCoords(d)

    local sdist = 149598000 -- distance from Earth to Sun in km

    local phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
    local inc = atan(sdist * sin(phi), m.dist - sdist * cos(phi))
    local angle = atan(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) -
                cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))

    return {
        fraction = (1 + cos(inc)) / 2,
        phase = 0.5 + 0.5 * inc * ternary(angle < 0, -1, 1) / math.pi,
        angle = angle
    }
end


local function hoursLater(date, h)
    return date + h * dayS / 24
end

-- calculations for moon rise/set times are based on http://www.stargazing.net/kepler/moonrise.html article

SunCalc.getMoonTimes = function (date, lat, lng)
    local t = date



    local hc = 0.133 * rad
    local h0 = SunCalc.getMoonPosition(t, lat, lng).altitude - hc
    local rise, set, ye, x1, x2

    -- go in 2-hour chunks, each time seeing if a 3-point quadratic curve crosses zero (which means rise or set)
    for i = 1, 24, 2 do
        local h1 = SunCalc.getMoonPosition(hoursLater(t, i), lat, lng).altitude - hc
        local h2 = SunCalc.getMoonPosition(hoursLater(t, i + 1), lat, lng).altitude - hc

        local a = (h0 + h2) / 2 - h1
        local b = (h2 - h0) / 2
        local xe = -b / (2 * a)
        ye = (a * xe + b) * xe + h1
        local d = b * b - 4 * a * h1
        local roots = 0

        if (d >= 0) then
            local dx = math.sqrt(d) / (math.abs(a) * 2)
            x1 = xe - dx
            x2 = xe + dx
            if (math.abs(x1) <= 1) then roots = roots + 1 end
            if (math.abs(x2) <= 1) then roots = roots + 1 end
            if (x1 < -1) then x1 = x2 end
        end

        if (roots == 1) then
            if (h0 < 0) then rise = i + x1
            else set = i + x1 end

        elseif (roots == 2) then
            rise = i + ternary(ye < 0, x2, x1)
            set = i + ternary(ye < 0, x1, x2)
        end

        if (rise and set) then break end

        h0 = h2
    end

    local result = {}

    if (rise) then result.rise = hoursLater(t, rise) end
    if (set) then result.set = hoursLater(t, set) end

    if (not rise and not set) then result[ternary(ye > 0, 'alwaysUp', 'alwaysDown')] = true end

    return result
end

return SunCalc
