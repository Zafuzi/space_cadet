function L(s) squids_log( s ); end

debug = false

-------------------------------------------------------
-- Some math stuff
-------------------------------------------------------
sqrt = math.sqrt
sin = math.sin
cos = math.cos
floor = math.floor
rand = math.random
abs = math.abs
atan2 = math.atan2
PI = math.pi
PI2 = PI * 2
PIH = PI / 2

-- return a number from 0.0 thru PI * for use as rot value
function azimuth(sx, sy, tx, ty)
    return atan2(ty - sy, tx - sx) + PIH
end

-- convert heading/angle to cartesion coords for distance 1.0
function cartes(az)
	az = az - PI
	return sin(az), -cos(az)
end

-- return a number between 0 and n -1 inclusive 
function roll(n)
	return math.random(0, n - 1)
end


-- ------------------------------------------------------------
-- Squid
-- ------------------------------------------------------------

function make_squid_set(fCreate, num)
	if num == nil then
		num = 1
	end

	-- take out and return the next available squid from the set
	local get = function(self)
		local n = self.n;
		local sq = self.squids[n];
		if sq.alive then
			return nil
		end
		n = n + 1;
		if(n > #(self.squids)) then
			n = 1;
		end
		self.n = n
		return sq
	end

	-- tick all squids in the set
	local tick = function(self) 
		for i = 1, #self.squids do
			local sq = self.squids[i]
			if sq.alive then
				sq:tick()
			end
		end
	end

	-- draw all squids in the set
	local draw = function(self) 
		for i = 1, #self.squids do
			local sq = self.squids[i]
			if sq.alive then
				sq:draw()
			end
		end
	end

	-- kill all squids in the set
	local kill = function(self)
		for i = 1, #self.squids do
			self.squids[i].alive = false
		end
	end

	local set = { n = 1, get = get, squids = {}, tick = tick, draw = draw, kill = kill }

	for i = 1, num do
		set.squids[i] = fCreate();
	end

	return set;
end

function get_image(file)
	local i, width, height = squids_image_load(file)
	if i then
		L( file .. ": " .. width .. "," .. height )
	else
		L( "load failed: " .. file )
	end
	return { idata = i, w = width, h = height }
end

function draw_image(img, dx, dy, a, r, px, py, sx, sy)
	r = (r / PI2) * 360;
	px = px * sx;
	py = py * sy;
	dx = math.floor(dx - px)
	dy = math.floor(dy - py)
	sx = math.floor(img.w * sx)
	sy = math.floor(img.h * sy)
	squids_image_draw( img.idata,
		0, 0, img.w, img.h,		-- src x, y, w, h
		dx, dy, sx, sy,			-- dst x, y, w, h
		px, py, r,				-- pivot x, y, rot
		a, 0					-- opacity, depth
		)
end


-- duplicate object via a shallow copy
function clone(proto)
  o = {}
  local inx = nil
  local val = nil
  repeat
    inx, val = next(proto, inx)
    if val then o[inx] = val end
  until (inx == nil)
  return o
end


-- apply some stupid semi-newtonian motion to a squid
function newton(sq)

	-- apply velocity
	sq.x = sq.x + sq.vx
	sq.y = sq.y + sq.vy
	-- apply gravity
	sq.vx = sq.vx + sq.gx
	sq.vy = sq.vy + sq.gy
	-- apply friction
	sq.vx = sq.vx - sq.fx
	sq.vy = sq.vy - sq.fy

	-- apply rotational velocity, acceleration, and friction 
	sq.r = sq.r + sq.vr 
	if(sq.r > PI2) then sq.r = sq.r - PI2 end
	if(sq.r < 0) then sq.r = sq.r + PI2 end
	sq.vr = sq.vr + sq.ra
	sq.vr = sq.vr - sq.rf

end

-- just draws a squid with it's upper left corner at its x,y 
function just_draw(sq)
	if(sq.alive and sq.img) then
		draw_image( sq.img, sq.x, sq.y, sq.a, sq.r, sq.px, sq.py, sq.sx, sq.sy );
	end
end


-- this is the basic squid object
Squid = {

	id = 0,

	img = nil,			-- default img?

	x = 0, y = 0,		-- position

	vx = 0, vy = 0,		-- velocity
	gx = 0, gy = 0,		-- gravity
	fx = 0, fy = 0,		-- friction

	sx = 1.0, sy = 1.0,	-- scale

	r = 0,				-- rotation
	vr = 0,				-- rotational velocity
	ra = 0,				-- rotational acceleration
	rf = 0,				-- rotational friction
	px = 0, py = 0,		-- pivot point

	a = 1.0,			-- alpha

	radius = 0,			-- for circular collisions

	alive = false,

	-- replaceable tick function
	tick = function(sq) newton(sq) end,

	-- replaceable draw function
	draw = function(sq) just_draw(sq) end,

}

function make_squid( img, x, y)
	local o = clone(Squid);

	o.img = nil
	if img ~= nil then
		o.img = img
		o.px = img.w / 2 -- indicating that pivot offset works
		o.py = img.h / 2
	end

	o.x, o.y = x or 0, y or 0;

	return o;
end



-- ------------------------------
-- Game
-- ------------------------------

local sw, sh = squids_get( "display_size" );
L( "display_size_pixels: " .. sw .. "," .. sh );

function SG(s) return s .. ": " .. squids_get( s ); end
L( SG( "squids_version" ) );
L( SG( "dev_code" ) );
L( SG( "platform" ) );
L( SG( "uik" ) );

tick_num = 0;
mx = sw * 0.5;
my = sw * 0.5;
alpha_dir = 1;

-- GRID GENERATION
grid_image = get_image("empty.bmp")
hover_grid_image = get_image("hover.bmp")
closed_grid_image = get_image("closed.bmp")
earth_image = get_image("earth.bmp")
pixi_image = get_image("pixi.bmp")
pixi_image_red = get_image("pixi_red.bmp")
dbg_image = get_image("earth.bmp")

grid_size = 5 
border_scale = grid_size + 1
grid_offset_x = sw / 2 - (grid_image.h / 2 * grid_size) 
grid_offset_y = sh / 2 - (grid_image.h / 2 * grid_size) 
grid = {}
for i = 0, grid_size, 1 do
	grid[i] = {}
	for k = 0, grid_size, 1 do
		grid[i][k] = make_squid( grid_image, grid_offset_x + i * grid_image.w, grid_offset_y + k * grid_image.h)
		grid[i][k].alive = true
	end
end

border_width = (hover_grid_image.w * border_scale) + (sw / 2) - hover_grid_image.w * border_scale / 2
border_height = (hover_grid_image.h * border_scale) + (sh / 2) - hover_grid_image.h * border_scale / 2
border_x = border_width - hover_grid_image.w * border_scale
border_y = border_height - hover_grid_image.h * border_scale

particles = {}
for i = 0, 10, 1 do
	local sq = make_squid( pixi_image, sw / 2, sh / 2)
	sq.alive = true

	coin = roll(2) == 0 and -1 or 1
	sq.vx = (math.random(1, 1000) / 1000) * coin 
	coin = roll(2) == 0 and -1 or 1
	sq.vy = (math.random(1, 1000) / 1000) * coin
	sq.tick = function(sq)
		if sq.x >= border_width then 
			sq.vx = math.random(1, 1000) / 1000 * -1
		end
		if sq.x <= border_x then 
			sq.vx = math.random(1, 1000) / 1000 
		end
		if sq.y >= border_height then 
			sq.vy = math.random(1, 1000) / 1000 * -1
		end
		if sq.y <= border_y then 
			sq.vy = math.random(1, 1000) / 1000 
		end

		sq.collision = false
		-- collide with closed tiles
		for j, row in pairs(grid) do
			for l, tile in pairs(row) do
				if tile.closed then
					if hit_rect_rect(tile.x, tile.y, tile.img.w, tile.img.h, sq.x, sq.y, sq.img.w, sq.img.h) then
						sq.vx = sq.vx * -1
						sq.vy = sq.vy * -1
						sq.collision = true
					end
				end
			end
		end

		if sq.collision then
			sq.img = pixi_image_red
		else
			sq.img = pixi_image
		end
		newton(sq)
	end

	particles[i] = sq
end

player_image = get_image( "yellow_rect.bmp" );
player = make_squid( player_image );
player.x = sw * 0.5;
player.y = sh * 0.5;
player.target_x = sw * 0.5;
player.target_y = sh * 0.5;
player.a = 1;
player.r = 0;
player.tick = function( sq )

	-- offx = abs( (sw / 2 ) - sq.x );
	-- offy = abs( (sh / 2 ) - sq.y );
	-- dist = 1 - ( sqrt( ( offx * offx ) + ( offy * offy ) ) * 0.011 );

	--sq.a = dist;
	--sq.sx = dist;
	--sq.sy = dist;

	sq.vx = ( sq.target_x - sq.x ) * 0.121;
	sq.vy = ( sq.target_y - sq.y ) * 0.121;
	-- sq.r = sq.r + (1 / 100);

	newton( sq );
end
player.alive = true;

img_star = get_image("logo.bmp");
L( "star " .. img_star.w .. "," .. img_star.h );
function tick_star(sq)
	-- sq.sx = sq.sx + 0.020
	-- sq.sy = sq.sy + 0.020
	newton( sq );
	sq.a = sq.a - 0.01
	if sq.a <= 0 then
		sq.alive = false;
	end
end
function newStar()
	local sq = make_squid(img_star)
	sq.tick = tick_star
	return sq
end
star_set = make_squid_set(newStar, 2000)
function make_star()
	local sq = star_set:get()
	if sq then
		sq.x = player.x -- sw * 0.5; 
		sq.y = player.y -- sh * 0.5; 
		-- sq.sx = 0.01 * (roll( 20 ) + 1);
		-- sq.sy = sq.sx
		sq.a = 1
		sq.vy = ( roll( 100 ) / 1000 ) * -200 ;
		--sq.vx = roll( 11 ) - 5;
		sq.vx = ( ( math.random( 0, sw ) / sw ) * 41) - 20;
		sq.gy = 1.0;
		sq.alive = true;
	end
end


font = squids_font_load("font_big_green.bmp");
vol = 30
squids_volume(vol)
sound = squids_sound_load("getin2it.wav");
sound_played = 0

function draw_all()

	-- player:draw();

	dy = 10 
	dx = (sw * 0.5) - 60;
	dy = (sh * 0.5) + 40;
    if debug then
        squids_font_draw("DEV", 10, 10, font, 1);
    end

	for i, pixi in pairs(particles) do
		pixi:draw()
	end
	for i, row in pairs(grid) do
		for k, tile in pairs(row) do
			tile:draw()
		end
	end
end

players = {} 
function tick_all()
	for i, pixi in pairs(particles) do
		pixi:tick()
	end
	for i, row in pairs(grid) do
		for k, tile in pairs(row) do
			if not tile.closed then
				if hit_rect_rect(mx, my, 1, 1, tile.x, tile.y, tile.img.w, tile.img.h) then
					tile.img = hover_grid_image
				else
					tile.img = grid_image
				end
			else
				tile.img = closed_grid_image
			end
			tile:tick()
		end
	end
	tick_num = tick_num + 1;
end


function event_handler( t, id, x, y ) 

	if t == SQUIDS_EVENT_TICK then

        tick_all();

		squids_draw_start();
        draw_all();
		squids_draw_end();

	end

	if t == SQUIDS_EVENT_POINTER_MOTION then
		mx = x;
		my = y;
	end

	if t == SQUIDS_EVENT_TOUCH_DOWN then
		mx = x;
		my = y;
		for i, row in pairs(grid) do
			for k, tile in pairs(row) do
				if hit_rect_rect(mx, my, 1, 1, tile.x, tile.y, tile.img.w, tile.img.h) then
					tile.closed = not tile.closed	
				end
			end
		end
	end

	-- L( "event " .. t .. " " .. id .. " " .. x .. "," .. y );
	if t == SQUIDS_EVENT_KEY_DOWN then
		key = id;
        if key == 61 then -- plus key
            vol = vol + 2;
            if vol > 100 then vol = 100 end
            squids_volume(vol);
        end
        if key == 45 then -- minus key
            vol = vol - 2;
            if vol < 0 then vol = 0 end
            squids_volume(vol);
        end
        if key == 111 then -- o
            sound_played = squids_sound_play(sound, vol);
            print(tostring(sound_played))
        end
        if key == 112 then -- p
            squids_sound_pause();
        end
        if key == 114 then -- r
            squids_sound_resume();
        end
        if key == 96 then -- `
            debug = not debug
        end
		--L("key down " .. key )
	end

	if t == SQUIDS_EVENT_KEY_UP then
		key = id;
		--L("key up " .. key )
	end

	if t == SQUIDS_EVENT_RESIZE then
		sw = x;
		sh = y;
		player.target_x = sw * 0.5;
		player.target_y = sh * 0.5;
	end

	if t == SQUIDS_EVENT_QUIT then
		squids_quit();
		return;
	end

end


squids_set( "tick_rate", 120 );

