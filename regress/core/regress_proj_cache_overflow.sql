--- Overflow proj cache
SELECT 13, count(*) FROM
(
  SELECT ST_Transform('SRID=4326; POINT(0 0)'::geometry, srid) AS g
  FROM (
    SELECT srid
    FROM spatial_ref_sys
    WHERE srid IN (
      2309, 2310, 2311, 4037, 3349, 4038, 3395, 3832, 3857, 3994, 3997, 5223, 5523, 5842, 6703, 6720, /**6722,**/ 6871, 6893/**, 7777, 7778, 7779, 7780, 7781, 7782, 7783, 7784, 7785, 7786, 7787**/, 8035, 8036, 32605, 32606, 32607, 32608, 32609, 32610, 32611, 32612, 32613/**, 32614, 32615**/, 32601, 32602, 32603, 32604/**, 32616, 32617**/, 32618, 32619, 32620, 32621, 32622, 32623, 32624, 32625, 32626, 32627, 32628, 32629, 32630, 32631, 32632, 32633, 32634, 32635, 32636, 32637, 32638, 32639, 32640, 32641, 32642, 32643/**, 32644, 32645, 32646, 32647, 32648**/, 32649, 32650, 32651, 32652, 32653, 32654, 32655, 32656, 32657, 32658, 32659, 32660/**, 32664, 32665, 32666, 32667**/, 32701, 32702, 32703, 32704, 32705, 32706, 32707, 32708, 32709, 32710, 32711, 32712, 32713/**, 32714, 32715, 32716, 32717**/, 32718, 32719, 32720, 32721, 32722, 32723, 32724, 32725, 32726, 32727, 32728, 32729, 32730, 32731, 32732, 32733, 32734, 32735, 32736, 32737, 32738, 32739, 32740, 32741, 32742/**, 32743, 32744, 32745, 32746, 32747**/, 32748, 32749, 32750

 )) _a
) _b
WHERE g IS NOT NULL;

--- The proj cache is also keyed on the definition strings passed to the
--- ST_Transform(geometry, text, text) family. All of the tests below only
--- compare results computed in this same session against each other, so no
--- coordinate values appear in the expected output.

--- test #14: definition A, then B, then A again. The third result must equal
--- the first (a cache scan that matches the wrong slot would break this) and
--- must differ from the second.
CREATE TABLE proj_cache_aba (n int, g geometry);
INSERT INTO proj_cache_aba VALUES (1, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
INSERT INTO proj_cache_aba VALUES (2, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=90 +datum=WGS84 +units=m +no_defs'));
INSERT INTO proj_cache_aba VALUES (3, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
SELECT 14,
	(SELECT ST_AsEWKT(g) FROM proj_cache_aba WHERE n = 1) = (SELECT ST_AsEWKT(g) FROM proj_cache_aba WHERE n = 3),
	(SELECT ST_AsEWKT(g) FROM proj_cache_aba WHERE n = 1) <> (SELECT ST_AsEWKT(g) FROM proj_cache_aba WHERE n = 2);
DROP TABLE proj_cache_aba;

--- test #15: overflow the proj cache with 200 distinct definition strings
CREATE TABLE proj_cache_str (n int, g geometry);
--- record the result for the first definition before it can be evicted
INSERT INTO proj_cache_str VALUES (1, ST_Transform('POINT(0 0)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=-99 +datum=WGS84 +units=m +no_defs'));
SELECT 15, count(*) FROM generate_series(-99, 100) k
WHERE ST_Transform('POINT(0 0)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	format('+proj=merc +lon_0=%s +datum=WGS84 +units=m +no_defs', k)) IS NOT NULL;

--- test #16: re-use the first definition, now that it has been evicted
INSERT INTO proj_cache_str VALUES (2, ST_Transform('POINT(0 0)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=-99 +datum=WGS84 +units=m +no_defs'));
SELECT 16,
	(SELECT ST_AsEWKT(g) FROM proj_cache_str WHERE n = 1) = (SELECT ST_AsEWKT(g) FROM proj_cache_str WHERE n = 2);
DROP TABLE proj_cache_str;

--- test #17: srid-keyed and string-keyed lookups interleaved in one session
CREATE TABLE proj_cache_mixed (n int, g geometry);
INSERT INTO proj_cache_mixed VALUES (1, ST_Transform('SRID=4326;POINT(16 48)'::geometry, 3857));
INSERT INTO proj_cache_mixed VALUES (2, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
INSERT INTO proj_cache_mixed VALUES (3, ST_Transform('SRID=4326;POINT(16 48)'::geometry, 3857));
INSERT INTO proj_cache_mixed VALUES (4, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
SELECT 17,
	(SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 1) = (SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 3),
	(SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 2) = (SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 4),
	(SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 1) <> (SELECT ST_AsEWKT(g) FROM proj_cache_mixed WHERE n = 2);
DROP TABLE proj_cache_mixed;

--- test #18: a definition that will not parse must still raise, and must not
--- be cached or leave a half-built entry behind
CREATE TABLE proj_cache_err (n int, g geometry);
INSERT INTO proj_cache_err VALUES (1, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
SELECT 18, ST_AsEWKT(ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'invalid projection'));

--- test #19: the good definition still resolves after the failed lookup
INSERT INTO proj_cache_err VALUES (2, ST_Transform('POINT(16 48)'::geometry,
	'+proj=longlat +datum=WGS84 +no_defs',
	'+proj=merc +lon_0=0 +datum=WGS84 +units=m +no_defs'));
SELECT 19,
	(SELECT ST_AsEWKT(g) FROM proj_cache_err WHERE n = 1) = (SELECT ST_AsEWKT(g) FROM proj_cache_err WHERE n = 2);
DROP TABLE proj_cache_err;
