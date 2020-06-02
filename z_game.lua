-- GRID GENERATION
grid_image = get_image("empty.png")
hover_grid_image = get_image("hover.png")
closed_grid_image = get_image("closed.png")
earth_image = get_image("earth.png")
pixi_image = get_image("pixi.png")
pixi_image_red = get_image("pixi_red.png")
dbg_image = get_image("earth.png")

grid_size = 5 
border_scale = grid_size + 1
grid_offset_x = sw / 2 - (grid_image:getHeight()/2 * grid_size) 
grid_offset_y = sh / 2 - (grid_image:getHeight() / 2 * grid_size) 
grid = {}
for i = 0, grid_size, 1 do
	grid[i] = {}
	for k = 0, grid_size, 1 do
		grid[i][k] = make_squid( grid_image, grid_offset_x + i * grid_image:getWidth(), grid_offset_y + k * grid_image:getHeight())
		grid[i][k].alive = true
	end
end

border_width = (hover_grid_image:getWidth() * border_scale) + (sw / 2) - hover_grid_image:getWidth() * border_scale / 2
border_height = (hover_grid_image:getHeight() * border_scale) + (sh / 2) - hover_grid_image:getHeight() * border_scale / 2
border_x = border_width - hover_grid_image:getWidth() * border_scale
border_y = border_height - hover_grid_image:getHeight() * border_scale

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
					if sq_collideRect(tile, sq) then
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

function love.mousepressed(x, y, button, istouch)
	if button == 1 then
		for i, row in pairs(grid) do
			for k, tile in pairs(row) do
				if mx >= tile.x - tile.img:getWidth() / 2 and 
				mx < (tile.x + tile.img:getWidth() / 2) and 
				my > tile.y - tile.img:getHeight() / 2 and 
				my < tile.y + tile.img:getHeight() / 2 then
					tile.closed = not tile.closed	
				end
			end
		end
	end
end

function love.update()
	sw = love.graphics.getWidth()
	sh = love.graphics.getHeight()
	mx = love.mouse.getX()
	my = love.mouse.getY()
	for i, pixi in pairs(particles) do
		pixi:tick()
	end
	for i, row in pairs(grid) do
		for k, tile in pairs(row) do
			if not tile.closed then
				if mx >= tile.x - tile.img:getWidth() / 2 and 
				   mx < (tile.x + tile.img:getWidth() / 2) and 
				   my > tile.y - tile.img:getHeight() / 2 and 
				   my < tile.y + tile.img:getHeight() / 2 then
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
end

function love.draw()
	love.graphics.draw(hover_grid_image, sw / 2 - (hover_grid_image:getWidth() / 2) * border_scale, sh / 2 - hover_grid_image:getHeight() / 2 * border_scale, 0, border_scale, border_scale)

	for i, pixi in pairs(particles) do
		pixi:draw()
	end

	for i, row in pairs(grid) do
		for k, tile in pairs(row) do
			tile:draw()
		end
	end
end