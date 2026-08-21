#!S:\Digital Projects\Administrative\scripts\Ruby193\bin\rubyw.exe
# 
# 
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
# Daxelject_GUI.rbw
# 
# Daxelject.rb and Daxelject_GUI.rbw written by Jeremiah Colonna-Romano
# 2012 - 2013. coded in Ruby v.1.9.3
# This tool transforms and processes raw three channel RGB values into a coordinate matrix by means of geometric projection methods
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
# Change Log
#
# Tk interface added 03/15/2013
# Added .SVG output 04/2013
# Added grid overlay to .SVG output 04/2013
# Moved several variables onto the GUI so they can be set by hand 04/2013
# Added Landscape Transformation to .SVG output. 05/2013
# Provided array positions within each daxel to hold explicit X and Y offset values 05/2013
# Added Tilt and Skew adjustments to the LST output 05/2013
# Added bounding box and ground plane to LST .SVG output 05/2013
# Added lighting falloff adjustment tools to interface 05/2013
# Added height mapping via channel value replacement from one daxel object to another 07/2013
#
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
# In The Works
# 
# Cross section tools: x and y axis polylines, z height contour hulls
# Periodic grid overlay onto mesh points
# Falloff lighting calculator
# Fade to neutral value down the z axis
# Export to .STL file
# Height map modes replacement, additive, subtractive, 
# Daxelject XML / TXT export.
# Development of DAXELJECT.XSD
# Intrinsic daxel nesting / variable density of data at each coordinate
# Textured .OBJ output mesh
# Import mapping for videostream x,y,f to Daxelspace x,z,y (frame data stacked as a standing file)
# Import mapping for file list x,y,f to Daxelspace x,y,z (frame data stacked as a pile)
# Stereogram render by slight rotation around the z axis between two renders of the same image
# "Flyby" video render stream
#
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# Requires
require "find"
require 'tk'


#--------------------------------------------------------------------------
#Setup 1

$headerfont_major = TkFont.new('arial 12 bold')
$headerfont = TkFont.new('arial 10 bold')
$displayfont = TkFont.new('arial 8 normal')

$selected_rawfile_name = TkVariable.new("") # this is the display variable for name and extention of the single rawfile you want to process
$rawfile = TkVariable.new("") # this is the path and filename of the single rawfile you want to process
$selected_h_map_rawfile_name = TkVariable.new("")
$h_map_rawfile = TkVariable.new("") # this is the path and filename of the single raw file for use as a height map
$selected_savefile_name = TkVariable.new("") # this is the display variable for name and extention of the single rawfile you want to process
$savefile = TkVariable.new("") # this is the path and filename of the single rawfile you want to process

$img_x_width = TkVariable.new("640") # this value is the "width" of the raw file being processed
$img_y_height = TkVariable.new("480") # this value is the "height" of the raw file being processed

$svg_render_style = TkVariable.new("points") # the value of this variable is controled by the svg render option checkbutton and can be "points" or "lines"
$transpose_z = TkVariable.new("natural z") # the value of this variable is controled by the trans z option checkbutton and can be "transpose z" or "natural z"
$histomap = TkVariable.new("histomap")

$skew = TkVariable.new(0) # amount of shift effect along the x axis as a function of (percentage skew over dim_y) times ypos
$tilt = TkVariable.new(0) # amount of shift effect along the y axis as a function of ypos minus (ypos over percentage tilt)

$falloff = TkVariable.new(50) # radius length of atmosphearic perspective effect
$ap_focus_x = TkVariable.new(50) # container for $ap_visualizer x coordinate click value
$ap_focus_y = TkVariable.new(50) # container for $ap_visualizer y coordinate click value
$ap_render = TkVariable.new("off") # the value of this variable is controled by the ap render option checkbutton and can be "on" or "off"

$y_count_trigger_entry = TkVariable.new(100)
$y_count_trigger_list = ["off"] # array to be filled with row number references indicating that something should be done on this row. 
$diagram_quanta = [[0, 0], [0, 0]] # an array holding two arrays for use as a drawing assembly line

$hex_lookup = []

$bg_hex = TkVariable.new("797979")
$shadow_one_hex = "717171"
$shadow_two_hex = "676767"
$shadow_three_hex = "636363"
$highlight_one_hex = "878787"
$highlight_two_hex = "959595"
$diagram_one_hex = "ff7979"
# $color_hex_ref = Hash.new()
# $color_hex_ref = {"desktop"=>"797979", "shadowone"=>"606060"}

$x_three_d_color_constant = 39 # colorspace channels in the x3d spec range from 0.0000 to 1.0000 effectivly 9999 values... so 9999 / 255 = ~39. this allows for an 8-bit color value to be multiplied by the constant and then catted on to "0." to generate valid colorspace values for export into x3d

$z_space_divisor_var = TkVariable.new(1) #
$zdepth_var = TkVariable.new(256) #
$grid_sections_var = TkVariable.new(3) #

$gs_files_dir = TkVariable.new("dir") # this is the directory where the green screened tif file image sections can be found for processing with imagemagick
$gs_processed_files_dir = TkVariable.new("save dir") # this is the directory where the green screened tif file image sections can be found for processing with imagemagick
$channel_mask_val = TkVariable.new("g") # this is the setting value used within the imagemagick command to select which color channel to make the blackout mask from
$tolerance_fuzz_val = TkVariable.new("65") # this is the setting value used within the imagemagick command to set the threshold for the channel blackout mask
$apply_times = TkVariable.new("1") # this is the setting value used within the imagemagick command to set the number of iteration times the morphology dilation will be applied during aperture mask edge cleanup procedure (a larger number removes more and shrinks the size of the aperture information)

#--------------------------------------------------------------------------
# setup 1 depth field components
$seq_in_directory = TkVariable.new("seq in dir") # this is the directory where the set of depth field camera jpg files are located
$seq_out_directory = TkVariable.new("seq out dir") # this is the directory where the set of depth field rgb raw files are located
$seq_ref = 256 # countdown tracking number used to assign sequence number to a daxel dz position each time a depth field image is analyzed for sharpness this counter is ticked down one until 0 and then no more images will be parsed
$conf_thresh = TkVariable.new(10)
$found_zero_value = true
#--------------------------------------------------------------------------
# start of class functions
#--------------------------------------------------------------------------
# Coordinate data element object Class
# 
#--------------------------------------------------------------------------
class Daxelject
	def initialize(dim_x, dim_y, rfile)
		@dim_x = dim_x.to_i # matrix toplevel the "width" or "x" dimention
		@dim_y = dim_y.to_i # matrix level 1 the "height" or "y" dimention
		@daxelspace = [] # the main array object
		@isospace = [] # array for rendering displacement values into isometric perspective
		@rawstream = [] # array for holding and processing the raw image values
		File.open(rfile, "rb") do |rawdata|
			@rawstream = rawdata.read.unpack('C*')
		end
	end
	
	def xval
		@dim_x
	end
	
	def yval
		@dim_y
	end
	
	def form # expands the main array object to its explicit size populating all of the coordinates with a baseline array
		dz = 0
		@dim_x.times {|dx|
			@daxelspace[dx] = []
			@dim_y.times {|dy|
				index = ((@dim_x * dy) + dx).to_i
				x_offset = 0
				y_offset = 0
				z_offset = 0
				@daxelspace[dx][dy] = ["r", "g", "b", dx, dy, dz, "#{index}", "#{x_offset}", "#{y_offset}", "#{z_offset}", []] # [0, 1, 2] used for color values, [3, 4, 5] used for coordinate values, [6] linear index of daxelspace matrix position, [7, 8, 9] coordinate shift values based on current projections tilt and skew, [10] is the array that holds the curve values used during confidence map assessment
			}
		}
	end
	
	def daxel(dx, dy, dz) # returns a value from the daxel data array at orthographic coordinates (x, y)
		@daxelspace[dx][dy][dz]
	end
	
	def daxel_getval(dx, dy, apos) # returns value from an array position (apos) in the @daxelspace data array at orthographic coordinates (x, y)
		return_val = @daxelspace[dx][dy][apos]
	end
	
	def daxel_putval(dx, dy, apos, update_value) # update a value in the daxel position array with a new value
		@daxelspace[dx][dy][apos] = update_value
	end
	
	def daxel_putarray(dx, dy, apos, insert_pos, update_value) # insert a value into an array located at a daxel position array
		@daxelspace[dx][dy][apos].insert(insert_pos, update_value)
	end
	
	def fill # iterates over all of the coordinate points of the main array and places r, g, b, values from the rawstream array, assumes raw data stream is an interleaved array of r g b values
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				# puts "x#{xval} y#{yval}"
				3.times {|i|
					@daxelspace[xval][yval][i] = @rawstream.shift.to_i
				}
				# puts "the rgb value of this daxel is #{@daxelspace[xval][yval][0]},#{@daxelspace[xval][yval][1]},#{@daxelspace[xval][yval][2]}"
			}
		}
	end
	
	def change_all_at(pos, val) # iterates over all of the coordinate points of the main array and places val at index position pos
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				@daxelspace[xval][yval][pos] = val
			}
		}
	end
	
	def relief(channel) # iterates over all of the coordinate points of the main array and maps the 8bit color value from a specified channel to the z "axis" coordinate value
		zval = 5
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				if channel == "r" then
					@daxelspace[xval][yval][zval] = (@daxelspace[xval][yval][0]).to_i
				elsif channel == "g" then
					@daxelspace[xval][yval][zval] = (@daxelspace[xval][yval][1]).to_i
				elsif channel == "b" then
					@daxelspace[xval][yval][zval] = (@daxelspace[xval][yval][2]).to_i
				end
			}
		}
	end
	
	def impose_histomap(channel, histobject)
		zval = 5
		@dim_y.times {|yval|
			@dim_x.times {|xval|
					@daxelspace[xval][yval][zval] = (histobject.daxel_getval(xval, yval, channel)).to_i
			}
		}	
	end
	
	def pack_disp_rgb(obj_output_file) # takes the z value from the daxelspace array and writes it to a .raw formatted file 3 times for each pixel (once for r, g, and b) this produces a monochrome displacement map for use with daxeljects other export functions
		# filedatatest = File.open("c:\\testing\\cps\\log.txt", "w")
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				3.times {|i|
					z_value_array = [nil]
					z_value_array[0] = @daxelspace[xval][yval][5].to_i
					if z_value_array[0] == 10 then
						z_value_array[0] = 11
					end
					# z_value = @daxelspace[xval][yval][5].to_s
					# z_value_array = z_value.lines.to_a
					# z_value_array[0] = z_value_array[0].to_i
					obj_output_file << z_value_array.pack('C*')
					# filedatatest.puts @daxelspace[xval][yval][5].to_i
				}
			}
		}
		obj_output_file.close
		# filedatatest.close
	end
	
	def pack_confidence_map_rgb(conf_obj_output_path) # takes the z value from the daxelspace array and writes it to a .raw formatted file 3 times for each pixel (once for r, g, and b) this produces a monochrome displacement map for use with daxeljects other export functions
		 conf_obj_output_file = File.open(conf_obj_output_path, "a")
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				3.times {|i|
					z_value_array = [nil]
					z_value_array[0] = @daxelspace[xval][yval][1].to_i
					if z_value_array[0] == 10 then
						z_value_array[0] = 11
					end
					conf_obj_output_file << z_value_array.pack('C*')
				}
			}
		}
		conf_obj_output_file.close
	end
	
	def transpose_z_values # iterates over all of the coordinate points of the main array and maps the 8bit color value from a specified channel to the z "axis" coordinate value
		zval = 5 # 5 is the z data array position in a daxelspace object 
		@dim_y.times {|yval|
			@dim_x.times {|xval|
					@daxelspace[xval][yval][zval] = 255 - (@daxelspace[xval][yval][zval]).to_i # flip the location of the vertex across the gamut of the z axis
			}
		}
	end
	
	def explicate_iso_offsets # iterates over all of the coordinate points of the main array and calculates the projection offset shifted values and applies them to their daxel
		# @daxelspace[dx][dy] = ["r", "g", "b", dx, dy, dz, "#{index}", "#{x_offset}", "#{y_offset}", "#{z_offset}"]
		@dim_y.times {|yval|
			@dim_x.times {|xval|
				if $skew != 0 then
					@daxelspace[xval][yval][7] = ((((@dim_x.to_f / 100) * ($skew.to_f / @dim_y).to_f) * yval).to_i + xval) # calculates the x axis shifted value for this daxel location and applies it to x_offset
				else
					@daxelspace[xval][yval][7] = @daxelspace[xval][yval][3]
				end
			
				if $tilt != 0 then
					@daxelspace[xval][yval][8] = (yval - ((yval.to_f / 100).to_f * $tilt).to_i) # calculates the y axis shifted value for this daxel location and applies it to y_offset
				else
					@daxelspace[xval][yval][8] = @daxelspace[xval][yval][4]
				end
			}
		}
	end
	
	def bbox_coordinates # these refere to the 8 corners of the bounding box for the offset coordinate values of a landscape render. point sequence moves clockwise floor then ceiling
		
		x_arr_extent = (@dim_x - 1).to_i
		y_arr_extent = (@dim_y - 1).to_i
		
		@bbfx1 = @daxelspace[0][0][7].to_i
		@bbfy1 = @daxelspace[0][0][8].to_i
		
		@bbfx2 = @daxelspace[x_arr_extent][0][7].to_i
		@bbfy2 = @daxelspace[x_arr_extent][0][8].to_i
		
		@bbfx3 = @daxelspace[x_arr_extent][y_arr_extent][7].to_i
		@bbfy3 = @daxelspace[x_arr_extent][y_arr_extent][8].to_i
		
		@bbfx4 = @daxelspace[0][y_arr_extent][7].to_i
		@bbfy4 = @daxelspace[0][y_arr_extent][8].to_i
		
		@bbcx1 = @daxelspace[0][0][7].to_i
		@bbcy1 = (@daxelspace[0][0][8].to_i - $zdepth_var).to_i
		
		@bbcx2 = @daxelspace[x_arr_extent][0][7].to_i
		@bbcy2 = (@daxelspace[x_arr_extent][0][8].to_i - $zdepth_var).to_i
		
		@bbcx3 = @daxelspace[x_arr_extent][y_arr_extent][7].to_i
		@bbcy3 = (@daxelspace[x_arr_extent][y_arr_extent][8].to_i - $zdepth_var).to_i
		
		@bbcx4 = @daxelspace[0][y_arr_extent][7].to_i
		@bbcy4 = (@daxelspace[0][y_arr_extent][8].to_i - $zdepth_var).to_i
		
	end
	
#--------------------------------------------------------------------------
# class export functions

	def enumerate_vertex_list(obj_output_file) # exports a vertex list to the output file using the x y z data values from the coordinate level 
		@dim_y.times {|y|
			@dim_x.times {|x|
				obj_output_file.puts "v #{@daxelspace[x][y][3]} #{@daxelspace[x][y][4]} #{@daxelspace[x][y][5]}"
			}
		}
		
	end
	
	def enumerate_surface_polygons(obj_output_file) # 
		@dim_y.times do |y|
			@dim_x.times do |x|
				if (x + 1) == @dim_x or (y + 1) == @dim_y then
					next
				else
					vert_a = @dim_x * y + x + 1
					vert_b = @dim_x * y + x + 2
					vert_c = @dim_x * y + @dim_x + x + 1
					vert_d = @dim_x * y + @dim_x + x + 2
					obj_output_file.puts "f #{vert_a} #{vert_b} #{vert_c}"
					obj_output_file.puts "f #{vert_b} #{vert_d} #{vert_c}"
				end
			end
		end
	end
	

# ---------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------
# Render IMAGE SVG
# ---------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------

	def render_image_svg(svg_output_file) # encode pixel data to image format (.svg colored line from daxelspace image map location to isospace displacement location)
		# setup
		zdepth = $zdepth_var #depth of the z dimentions data
		isx = @dim_x + zdepth
		isy = @dim_y + zdepth
		
		# svg header
		svg_output_file.puts '<?xml version="1.0" standalone="no"?>'
		svg_output_file.puts '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">'
		svg_output_file.puts "<svg width=\"#{isx}\" height=\"#{isy}\" viewBox=\"0 0 #{isx} #{isy}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">"
		svg_output_file.puts "<rect x=\"0\" y=\"0\" width=\"#{isx}\" height=\"#{isy}\" fill=\"##{$bg_hex}\" stroke=\"none\"/>"
		svg_output_file.puts "<line x1=\"#{@dim_x}\" y1=\"0\" x2=\"#{@dim_x}\" y2=\"#{@dim_y}\" style=\"stroke:#003300; stroke-linecap:round; stroke-width:1\"/>"
		
		
		
		# svg lines
		lines_array = []
		yone = 0
		z_space_divisor = $z_space_divisor_var # factor by which to shrink the display of data in the z dimention
		z_grid_height = (zdepth.to_f / z_space_divisor).to_i # the height of the maximum value of the render space
		z_grid_one = (z_grid_height.to_f / 3).to_i
		z_grid_two = ((z_grid_height.to_f / 3).to_f * 2).to_i
		grid_sections = $grid_sections_var # the number of grid line sections to appear in the rendering
		grid_interval = (@dim_y.to_f / grid_sections).to_i # number of lines between each grid line in the rendering
		grid_line_counter = grid_interval
		
		
		@dim_y.times {|y|

			@dim_x.times {|x|
				xone = @daxelspace[x][y][3].to_i
				yone = @daxelspace[x][y][4].to_i
				
				xtwo = (@daxelspace[x][y][5].to_f / z_space_divisor).to_i + xone
				ytwo = (@daxelspace[x][y][5].to_f / z_space_divisor).to_i + yone
				
				r = @daxelspace[x][y][0].to_i
				g = @daxelspace[x][y][1].to_i
				b = @daxelspace[x][y][2].to_i
				
				line_color_value = "#{$hex_lookup[r]}#{$hex_lookup[g]}#{$hex_lookup[b]}" # composes 6-digit hex color value string from 3 3-digit rgb values by means of the $hex_lookup 2d array index value
				
				if line_color_value != "000000" && $svg_render_style.value == "lines" # appends svg line elements to an array for writing to file later
					lines_array << "<line x1=\"#{xone}\" y1=\"#{yone}\" x2=\"#{xtwo}\" y2=\"#{ytwo}\" style=\"stroke:##{line_color_value}; stroke-linecap:round; stroke-width:1\"/>"
				end
				if line_color_value != "000000" && $svg_render_style.value == "points" # appends svg circle ("points") elements to an array for writing to file later
					lines_array << "<circle cx=\"#{xtwo}\" cy=\"#{ytwo}\" r=\"1\" fill=\"##{line_color_value}\"/>"
				end
			}
			
			if grid_line_counter == 0
				#
				xone_a = z_grid_one
				yone_a = z_grid_one + yone
				
				xtwo_a = z_grid_one + @dim_x
				ytwo_a = z_grid_one + yone
				#----------------------------------
				xone_b = z_grid_two
				yone_b = z_grid_two + yone
				
				xtwo_b = z_grid_two + @dim_x
				ytwo_b = z_grid_two + yone
				#----------------------------------
				xone_c = z_grid_height
				yone_c = z_grid_height + yone
				
				xtwo_c = z_grid_height + @dim_x
				ytwo_c = z_grid_height + yone
				#----------------------------------
				xba = @dim_x
				yba = yone
				
				xbb = @dim_x + z_grid_height
				ybb = yone + z_grid_height
				#----------------------------------
				xfa = 0
				yfa = yone
				
				xfb = z_grid_height
				yfb = yone + z_grid_height
				
				# grid baseline back
				lines_array << "<line x1=\"#{xfa}\" y1=\"#{yfa}\" x2=\"#{xfb}\" y2=\"#{yfb}\" style=\"stroke:#006600; stroke-linecap:round; stroke-width:1\"/>"
				
				# grid baseline front
				lines_array << "<line x1=\"#{xba}\" y1=\"#{yba}\" x2=\"#{xbb}\" y2=\"#{ybb}\" style=\"stroke:#009900; stroke-linecap:round; stroke-width:1\"/>"
				
				# grid baseline
				lines_array << "<line x1=\"0\" y1=\"#{yone}\" x2=\"#{@dim_x}\" y2=\"#{yone}\" style=\"stroke:#003300; stroke-linecap:round; stroke-width:1\"/>"
				
				# grid 1/3 z height line
				lines_array << "<line x1=\"#{xone_a}\" y1=\"#{yone_a}\" x2=\"#{xtwo_a}\" y2=\"#{ytwo_a}\" style=\"stroke:#006600; stroke-linecap:round; stroke-width:1\"/>"
				
				# grid 2/3 z height line
				lines_array << "<line x1=\"#{xone_b}\" y1=\"#{yone_b}\" x2=\"#{xtwo_b}\" y2=\"#{ytwo_b}\" style=\"stroke:#009900; stroke-linecap:round; stroke-width:1\"/>"
				
				# grid 3/3 z height line
				lines_array << "<line x1=\"#{xone_c}\" y1=\"#{yone_c}\" x2=\"#{xtwo_c}\" y2=\"#{ytwo_c}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
				
				grid_line_counter = grid_interval
			end
			grid_line_counter = grid_line_counter - 1
		}
		
		
		lines_array.reverse_each {|line|
			svg_output_file.puts line
		}
		
		# svg footer
		# attribution note
		bottom_of_render_cube = @dim_y + z_grid_height
		footer_loc_ylone = bottom_of_render_cube + 10
		footer_loc_yltwo = bottom_of_render_cube + 16
		footer_loc_ylthree = bottom_of_render_cube + 22
		
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_ylone}\" font-family=\"Arial\" font-size=\"4\" fill=\"#80a090\">Image created with Daxelject_GUI.rbw</text>"
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_yltwo}\" font-family=\"Arial\" font-size=\"4\" fill=\"#80a090\">Images and daxelject code by Jeremiah Colonna Romano 2013</text>"
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_ylthree}\" font-family=\"Arial\" font-size=\"4\" fill=\"#80a090\">RAW source file: #{$selected_rawfile_name.value}</text>"
		
		# base level bounding square
		svg_output_file.puts "<line x1=\"0\" y1=\"0\" x2=\"#{@dim_x}\" y2=\"0\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"0\" y1=\"0\" x2=\"0\" y2=\"#{@dim_y}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		
		# 1/3 and 2/3 grid lines on the top of the render cube
		svg_output_file.puts "<line x1=\"#{z_grid_one}\" y1=\"#{z_grid_one}\" x2=\"#{(@dim_x + z_grid_one)}\" y2=\"#{z_grid_one}\" style=\"stroke:#006600; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"#{z_grid_two}\" y1=\"#{z_grid_two}\" x2=\"#{(@dim_x + z_grid_two)}\" y2=\"#{z_grid_two}\" style=\"stroke:#009900; stroke-linecap:round; stroke-width:1\"/>"
		
		# grid height projection legs
		svg_output_file.puts "<line x1=\"0\" y1=\"0\" x2=\"#{z_grid_height}\" y2=\"#{z_grid_height}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"#{@dim_x}\" y1=\"0\" x2=\"#{(@dim_x + z_grid_height)}\" y2=\"#{z_grid_height}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"0\" y1=\"#{@dim_y}\" x2=\"#{z_grid_height}\" y2=\"#{(@dim_y + z_grid_height)}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		
		# top level bounding square
		svg_output_file.puts "<line x1=\"#{z_grid_height}\" y1=\"#{z_grid_height}\" x2=\"#{(@dim_x + z_grid_height)}\" y2=\"#{z_grid_height}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"#{(@dim_x + z_grid_height)}\" y1=\"#{z_grid_height}\" x2=\"#{(@dim_x + z_grid_height)}\" y2=\"#{(@dim_y + z_grid_height)}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"#{(@dim_x + z_grid_height)}\" y1=\"#{(@dim_y + z_grid_height)}\" x2=\"#{z_grid_height}\" y2=\"#{(@dim_y + z_grid_height)}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		svg_output_file.puts "<line x1=\"#{z_grid_height}\" y1=\"#{(@dim_y + z_grid_height)}\" x2=\"#{z_grid_height}\" y2=\"#{z_grid_height}\" style=\"stroke:#00CC00; stroke-linecap:round; stroke-width:1\"/>"
		
		# SVG end tag
		svg_output_file.puts "</svg>"
		svg_output_file.close
	end
	
# ---------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------
# Render Landscape SVG
# ---------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------

	def render_landscape_svg(svg_output_file)
		# setup
		border_padding = 20
		comment_area_height = 150
		
		zdepth = $zdepth_var #depth of the z dimentions data defaults to 256
		isx = @dim_x + (@dim_x + (border_padding * 2))
		isy = @dim_y + zdepth + (border_padding * 2) + comment_area_height
		
		# svg header
		svg_output_file.puts '<?xml version="1.0" standalone="no"?>'
		svg_output_file.puts '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">'
		svg_output_file.puts "<svg width=\"#{isx}\" height=\"#{isy}\" viewBox=\"-#{border_padding} -#{(zdepth + border_padding)} #{isx} #{isy}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">" 
		svg_output_file.puts "<rect x=\"-#{border_padding}\" y=\"-#{(zdepth + border_padding)}\" width=\"#{isx}\" height=\"#{isy}\" fill=\"##{$bg_hex}\" stroke=\"none\"/>"
		# svg_output_file.puts "<polyline fill=\"##{$shadow_two_hex}\" points=\"#{@bbcx1},#{@bbcy1},#{@bbcx2},#{@bbcy2},#{@bbfx2},#{@bbfy2},#{@bbfx1},#{@bbfy1},#{@bbcx1},#{@bbcy1}\" stroke=\"##{$shadow_two_hex}\" stroke-linecap=\"round\" stroke-width=\"2\"/>" # back side of the display cube
		svg_output_file.puts "<polyline fill=\"##{$shadow_one_hex}\" points=\"#{@bbfx1},#{@bbfy1},#{@bbfx2},#{@bbfy2},#{@bbfx3},#{@bbfy3},#{@bbfx4},#{@bbfy4},#{@bbfx1},#{@bbfy1}\" stroke=\"##{$shadow_one_hex}\" stroke-linecap=\"round\" stroke-width=\"2\"/>" # bottom of the display cube
		svg_output_file.puts "<polyline fill=\"##{$shadow_three_hex}\" points=\"#{@bbcx2},#{@bbcy2},#{@bbcx3},#{@bbcy3},#{@bbfx3},#{@bbfy3},#{@bbfx2},#{@bbfy2},#{@bbcx2},#{@bbcy2}\" stroke=\"##{$shadow_three_hex}\" stroke-linecap=\"round\" stroke-width=\"2\"/>" # right side of the display cube
		
		# svg lines, points
		lines_array = []
		yone = 0
		z_space_divisor = $z_space_divisor_var # factor by which to shrink the display of data in the z dimention
		z_grid_height = (zdepth.to_f / z_space_divisor).to_i # the height of the maximum value of the render space
		z_grid_one = (z_grid_height.to_f / 3).to_i
		z_grid_two = ((z_grid_height.to_f / 3).to_f * 2).to_i
		grid_sections = $grid_sections_var # the number of grid line sections to appear in the rendering
		grid_interval = (@dim_y.to_f / grid_sections).to_i # number of lines between each grid line in the rendering
		grid_line_counter = grid_interval
		
		
		@dim_y.times {|y|

			@dim_x.times {|x|
				xone = @daxelspace[x][y][7].to_i
				yone = @daxelspace[x][y][8].to_i
				
				xtwo = @daxelspace[x][y][7].to_i
				ytwo = (yone - (@daxelspace[x][y][5].to_f / z_space_divisor).to_i)
				
				r = @daxelspace[x][y][0].to_i
				g = @daxelspace[x][y][1].to_i
				b = @daxelspace[x][y][2].to_i
				
				line_color_value = "#{$hex_lookup[r]}#{$hex_lookup[g]}#{$hex_lookup[b]}" # composes 6-digit hex color value string from 3 3-digit rgb values by means of the $hex_lookup 2d array index value
				
				if line_color_value != "000000" && $svg_render_style.value == "lines" # appends svg line elements to an array for writing to file later
					lines_array << "<line x1=\"#{xone}\" y1=\"#{yone}\" x2=\"#{xtwo}\" y2=\"#{ytwo}\" style=\"stroke:##{line_color_value}; stroke-linecap:round; stroke-width:1\"/>"
				end
				if line_color_value != "000000" && $svg_render_style.value == "points" # appends svg circle ("points") elements to an array for writing to file later
					lines_array << "<circle cx=\"#{xtwo}\" cy=\"#{ytwo}\" r=\"1\" fill=\"##{line_color_value}\"/>"
				end
			}
		}
		
		
		lines_array.each {|line| # this is a .reverse_each loop in other svg output modes
			svg_output_file.puts line
		}
		
		# bounding box top level
		svg_output_file.puts "<polyline fill=\"none\" points=\"#{@bbcx1},#{@bbcy1},#{@bbcx2},#{@bbcy2},#{@bbcx3},#{@bbcy3},#{@bbcx4},#{@bbcy4},#{@bbcx1},#{@bbcy1}\" stroke=\"##{$highlight_two_hex}\" stroke-linecap=\"round\" stroke-width=\"1\"/>"
		
		# svg footer
		# attribution note
		bottom_of_render_cube = (@dim_y - ((@dim_y.to_f / 100).to_f * $tilt).to_i) # this is the bottom edge of the data in the display
		footer_loc_ylone = bottom_of_render_cube + 10
		footer_loc_yltwo = bottom_of_render_cube + 20
		footer_loc_ylthree = bottom_of_render_cube + 30
		footer_loc_ylfour = bottom_of_render_cube + 40
		
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_ylone}\" font-family=\"Arial\" font-size=\"8\" fill=\"#80a090\">Image created with Daxelject_GUI.rbw</text>"
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_yltwo}\" font-family=\"Arial\" font-size=\"8\" fill=\"#80a090\">Images and daxelject code by Jeremiah Colonna Romano 2013</text>"
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_ylthree}\" font-family=\"Arial\" font-size=\"8\" fill=\"#80a090\">RAW source file: #{$selected_rawfile_name.value}</text>"
		svg_output_file.puts "<text x=\"5\" y=\"#{footer_loc_ylfour}\" font-family=\"Arial\" font-size=\"8\" fill=\"#80a090\">TILT:#{$tilt}, SKEW:#{$skew}, ZDEPTH:#{$zdepth_var}, ZSPACEDIV:#{$z_space_divisor_var}, ZAXIS:#{$transpose_z}</text>"
		
		# SVG end tag
		svg_output_file.puts "</svg>"
		svg_output_file.close
	end
	
	def export_x_three_d(x_three_d_output_file)
		x_three_d_output_file.puts '<?xml version="1.0" encoding="UTF-8"?>'
		x_three_d_output_file.puts '<!DOCTYPE X3D PUBLIC "ISO//Web3D//DTD X3D 3.2//EN" "http://www.web3d.org/specifications/x3d-3.2.dtd">'
		x_three_d_output_file.puts '<X3D profile=\'Interchange\' version=\'3.2\' xmlns:xsd=\'http://www.w3.org/2001/XMLSchema-instance\' xsd:noNamespaceSchemaLocation=\'http://www.web3d.org/specifications/x3d-3.2.xsd\' id=\'x3d_object\' width=\'2000px\' height=\'1000px\'>'
		x_three_d_output_file.puts '<Scene>'
		x_three_d_output_file.puts '<background groundColor=\'0 0 0\' skyColor=\'0,0,0\' />'
		x_three_d_output_file.puts "<Viewpoint orientation=\'0 0 3.141 3.141\' position=\'#{(@dim_x.to_f / 2).to_i} #{(@dim_y.to_f / 2).to_i} 2000\' centerOfRotation=\'#{(@dim_x.to_f / 2).to_i} #{(@dim_y.to_f / 2).to_i} 0\'/> "
		x_three_d_output_file.puts '<Shape>'
		x_three_d_output_file.puts '<PointSet>'
		x_three_d_output_file.puts '<Color color="'
		
		@dim_y.times {|y|
			@dim_x.times {|x|
				r = (@daxelspace[x][y][0].to_i * $x_three_d_color_constant).to_s.rjust(4, '0') # convert 3 digit 8-bit color channel value into x3d color format values ie. 255 = 0.9945, or 001 = 0.0039
				g = (@daxelspace[x][y][1].to_i * $x_three_d_color_constant).to_s.rjust(4, '0') # x3d spec interperates 0.78 to be 0.7800, so all values are padded to four digits to render correctly all values less than 0.1000 ie. 0.0078
				b = (@daxelspace[x][y][2].to_i * $x_three_d_color_constant).to_s.rjust(4, '0')
				x_three_d_output_file.puts "0.#{r} 0.#{g} 0.#{b}"
			}
		}
		
		x_three_d_output_file.puts '"/>'
		x_three_d_output_file.puts '<Coordinate point="'
		
		@dim_y.times {|y|
			@dim_x.times {|x|
				z = (@daxelspace[x][y][5].to_f / $z_space_divisor_var).to_f
				x_three_d_output_file.puts "#{@daxelspace[x][y][3]} #{@daxelspace[x][y][4]} #{z}"
			}
		}		
		
		x_three_d_output_file.puts '"/>'
		x_three_d_output_file.puts '</PointSet>'
		x_three_d_output_file.puts '</Shape>'
		x_three_d_output_file.puts '</Scene>'
		x_three_d_output_file.puts '</X3D>'
		x_three_d_output_file.close
	end
	
	def export_wrl(wrl_output_file)
		
		coord_index_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		coord_color_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		point_array = []
		color_array = []
		colorindex = []
		coordindex = []
		cvx = (@dim_x.to_f / 2).to_i # these are the x y and z vertex positions for the "center" fan vertex used to close off the bottom of the model
		cvy =(@dim_y.to_f / 2).to_i
		cvz = 0
		
		wrl_output_file.puts '#VRML V2.0 utf8'
		wrl_output_file.puts '# export from Daxelject software by Jeremiah Colonna-Romano'
		
		wrl_output_file.puts 'Viewpoint {'
		wrl_output_file.puts "position #{(@dim_x.to_f / 2).to_i} #{(@dim_y.to_f / 2).to_i} 2000"
		wrl_output_file.puts 'orientation 0 0 1 0'
		wrl_output_file.puts '}' # closes viewpoint
		

		# surface relief loop
		(@dim_y - 1).times {|y| # this loop iterates across all of the relief vertex locations and populates the arrays used to write the four dataset nodes used when writing out the indexedfaceset geometry node
			(@dim_x - 1).times {|x|
				
				ax = x
				ay = y
				az = (@daxelspace[x][y][5].to_f / $z_space_divisor_var).to_i
				
				bx = x + 1
				by = y
				bz = (@daxelspace[x + 1][y][5].to_f / $z_space_divisor_var).to_i
				
				cx = x
				cy = y + 1
				cz = (@daxelspace[x][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = y + 1
				dz = (@daxelspace[x + 1][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				r = (@daxelspace[x][y][0].to_i * $x_three_d_color_constant).to_s.rjust(4, '0') # convert 3 digit 8-bit color channel value into x3d color format values ie. 255 = 0.9945, or 001 = 0.0039
				g = (@daxelspace[x][y][1].to_i * $x_three_d_color_constant).to_s.rjust(4, '0') # wrl spec interperates 0.78 to be 0.7800, so all values are padded to four digits to render correctly all values less than 0.1000 ie. 0.0078
				b = (@daxelspace[x][y][2].to_i * $x_three_d_color_constant).to_s.rjust(4, '0')
				color_array << "0.#{r} 0.#{g} 0.#{b},"
				
				point_array << "#{ax} #{ay} #{az}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

				
				point_array << "#{bx} #{by} #{bz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				colorindex << "#{coord_color_ticker}"
			

				point_array << "#{bx} #{by} #{bz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{dx} #{dy} #{dz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				colorindex << "#{coord_color_ticker}"
			

			
				coord_color_ticker = coord_color_ticker + 1
			}
		}
		
		# output the surface relief to the wrl file		
		wrl_output_file.puts 'Shape {'
		wrl_output_file.puts 'appearance Appearance {'
		wrl_output_file.puts 'material Material {'
		wrl_output_file.puts '}' # closes material
		wrl_output_file.puts '}' # closes appearance
		wrl_output_file.puts 'geometry IndexedFaceSet {'
		wrl_output_file.puts 'coord Coordinate {'
		wrl_output_file.puts 'point [' # here is the list of vertex points from held in the point_array
		point_array.each { |vertex| wrl_output_file.puts vertex }
		wrl_output_file.puts ']' # closes point
		wrl_output_file.puts '}' # closes coord Coordinate
		wrl_output_file.puts 'colorPerVertex FALSE' # so each face will get a color from the colorindex array
		wrl_output_file.puts 'color Color {'
		wrl_output_file.puts 'color ['
		color_array.each { |rgbvals| wrl_output_file.puts rgbvals }
		wrl_output_file.puts ']' # closes color
		wrl_output_file.puts '}' # closes color Color
		wrl_output_file.puts 'colorIndex ['
		colorindex.each { |rgbindex| wrl_output_file.puts rgbindex }
		wrl_output_file.puts ']' # closes colorIndex
		wrl_output_file.puts 'coordIndex ['
		coordindex.each { |vertexindex| wrl_output_file.puts vertexindex }
		wrl_output_file.puts ']'
		wrl_output_file.puts '}' # closes geometry IndexedFaceSet for the relief section
		wrl_output_file.puts '}' # closes shape
		
		
		# dataset array reset for top quadrant portion
		coord_index_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		point_array = []
		coordindex = []
		
		
		@dim_x.times {|x| # this loop walks off the top quadrant vertexes writing the curtain and fan for that quadrant
			unless x >= @dim_x - 1
				ax = x # the A and B vertex coordinates are located on the baseline of the model
				ay = 0
				az = 0
				
				bx = x + 1
				by = 0
				bz = 0
				
				cx = x # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = 0
				cz = (@daxelspace[x][0][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = 0
				dz = (@daxelspace[x + 1][0][5].to_f / $z_space_divisor_var).to_i
				
				point_array << "#{ax} #{ay} #{az}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

				
				point_array << "#{bx} #{by} #{bz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1

			

				point_array << "#{bx} #{by} #{bz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{dx} #{dy} #{dz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				
				
				
				point_array << "#{cvx} #{cvy} #{cvz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{ax} #{ay} #{az}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
			end
		}

		# output the top quadrant to the wrl file		
		wrl_output_file.puts 'Shape {'
		wrl_output_file.puts 'appearance Appearance {'
		wrl_output_file.puts 'material Material {'
		wrl_output_file.puts '}' # closes material
		wrl_output_file.puts '}' # closes appearance
		wrl_output_file.puts 'geometry IndexedFaceSet {'
		wrl_output_file.puts 'coord Coordinate {'
		wrl_output_file.puts 'point [' # here is the list of vertex points from held in the point_array
		point_array.each { |vertex| wrl_output_file.puts vertex }
		wrl_output_file.puts ']' # closes point
		wrl_output_file.puts '}' # closes coord Coordinate
		wrl_output_file.puts 'coordIndex ['
		coordindex.each { |vertexindex| wrl_output_file.puts vertexindex }
		wrl_output_file.puts ']'
		wrl_output_file.puts '}' # closes geometry IndexedFaceSet for the relief section
		wrl_output_file.puts '}' # closes shape
		
		
		# dataset array reset for bottom quadrant portion
		coord_index_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		point_array = []
		coordindex = []
		
		
		
		@dim_x.times {|x| # this loop walks off the bottom quadrant vertexes writing the curtain and fan for that quadrant
			unless x >= @dim_x - 1
				ax = x # the A and B vertex coordinates are located on the baseline of the model
				ay = @dim_y - 1
				az = 0
				
				bx = x + 1
				by = @dim_y - 1
				bz = 0
				
				cx = x # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = @dim_y - 1
				cz = (@daxelspace[x][@dim_y - 1][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = @dim_y - 1
				dz = (@daxelspace[x + 1][@dim_y - 1][5].to_f / $z_space_divisor_var).to_i
				
				point_array << "#{cx} #{cy} #{cz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

				
				point_array << "#{bx} #{by} #{bz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{ax} #{ay} #{az}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1

			

				point_array << "#{cx} #{cy} #{cz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{dx} #{dy} #{dz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				
				
				
				point_array << "#{ax} #{ay} #{az}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cvx} #{cvy} #{cvz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
			end
		}

		# output the bottom quadrant to the wrl file		
		wrl_output_file.puts 'Shape {'
		wrl_output_file.puts 'appearance Appearance {'
		wrl_output_file.puts 'material Material {'
		wrl_output_file.puts '}' # closes material
		wrl_output_file.puts '}' # closes appearance
		wrl_output_file.puts 'geometry IndexedFaceSet {'
		wrl_output_file.puts 'coord Coordinate {'
		wrl_output_file.puts 'point [' # here is the list of vertex points from held in the point_array
		point_array.each { |vertex| wrl_output_file.puts vertex }
		wrl_output_file.puts ']' # closes point
		wrl_output_file.puts '}' # closes coord Coordinate
		wrl_output_file.puts 'coordIndex ['
		coordindex.each { |vertexindex| wrl_output_file.puts vertexindex }
		wrl_output_file.puts ']'
		wrl_output_file.puts '}' # closes geometry IndexedFaceSet for the relief section
		wrl_output_file.puts '}' # closes shape
		
		
		# dataset array reset for left quadrant portion
		coord_index_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		point_array = []
		coordindex = []
		
		
		@dim_y.times {|y| # this loop walks off the left quadrant vertexes writing the curtain and fan for that quadrant
			unless y >= @dim_y - 1
				ax = 0 # the A and B vertex coordinates are located on the baseline of the model
				ay = y
				az = 0
				
				bx = 0
				by = y + 1
				bz = 0
				
				cx = 0 # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = y
				cz = (@daxelspace[0][y][5].to_f / $z_space_divisor_var).to_i
				
				dx = 0
				dy = y + 1
				dz = (@daxelspace[0][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				point_array << "#{cx} #{cy} #{cz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

				
				point_array << "#{bx} #{by} #{bz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{ax} #{ay} #{az}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1

			

				point_array << "#{cx} #{cy} #{cz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{dx} #{dy} #{dz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				
				
				
				point_array << "#{ax} #{ay} #{az}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cvx} #{cvy} #{cvz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
			end
		}

		# output the left quadrant to the wrl file		
		wrl_output_file.puts 'Shape {'
		wrl_output_file.puts 'appearance Appearance {'
		wrl_output_file.puts 'material Material {'
		wrl_output_file.puts '}' # closes material
		wrl_output_file.puts '}' # closes appearance
		wrl_output_file.puts 'geometry IndexedFaceSet {'
		wrl_output_file.puts 'coord Coordinate {'
		wrl_output_file.puts 'point [' # here is the list of vertex points from held in the point_array
		point_array.each { |vertex| wrl_output_file.puts vertex }
		wrl_output_file.puts ']' # closes point
		wrl_output_file.puts '}' # closes coord Coordinate
		wrl_output_file.puts 'coordIndex ['
		coordindex.each { |vertexindex| wrl_output_file.puts vertexindex }
		wrl_output_file.puts ']'
		wrl_output_file.puts '}' # closes geometry IndexedFaceSet for the relief section
		wrl_output_file.puts '}' # closes shape
		
		
		# dataset array reset for right quadrant portion
		coord_index_ticker = 0 # this ticker must be reset to 0 at the beginning of each IndexedFaceSet node export loop
		point_array = []
		coordindex = []
		
		
		@dim_y.times {|y| # this loop walks off the right quadrant vertexes writing the curtain and fan for that quadrant
			unless y >= @dim_y - 1
				ax = @dim_x - 1 # the A and B vertex coordinates are located on the baseline of the model
				ay = y
				az = 0
				
				bx = @dim_x - 1
				by = y + 1
				bz = 0
				
				cx = @dim_x - 1 # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = y
				cz = (@daxelspace[@dim_x - 1][y][5].to_f / $z_space_divisor_var).to_i
				
				dx = @dim_x - 1
				dy = y + 1
				dz = (@daxelspace[@dim_x - 1][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				point_array << "#{ax} #{ay} #{az}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

				
				point_array << "#{bx} #{by} #{bz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "A"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1

			

				point_array << "#{bx} #{by} #{bz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{dx} #{dy} #{dz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{cx} #{cy} #{cz}," # face "B"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
				
				
				
				point_array << "#{cvx} #{cvy} #{cvz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{bx} #{by} #{bz}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coord_index_ticker = coord_index_ticker + 1

			
				point_array << "#{ax} #{ay} #{az}," # face "C"
				coordindex << "#{coord_index_ticker}, "
				coordindex << "-1, "
				coord_index_ticker = coord_index_ticker + 1
			end
		}

		# output the right quadrant to the wrl file		
		wrl_output_file.puts 'Shape {'
		wrl_output_file.puts 'appearance Appearance {'
		wrl_output_file.puts 'material Material {'
		wrl_output_file.puts '}' # closes material
		wrl_output_file.puts '}' # closes appearance
		wrl_output_file.puts 'geometry IndexedFaceSet {'
		wrl_output_file.puts 'coord Coordinate {'
		wrl_output_file.puts 'point [' # here is the list of vertex points from held in the point_array
		point_array.each { |vertex| wrl_output_file.puts vertex }
		wrl_output_file.puts ']' # closes point
		wrl_output_file.puts '}' # closes coord Coordinate
		wrl_output_file.puts 'coordIndex ['
		coordindex.each { |vertexindex| wrl_output_file.puts vertexindex }
		wrl_output_file.puts ']'
		wrl_output_file.puts '}' # closes geometry IndexedFaceSet for the relief section
		wrl_output_file.puts '}' # closes shape
		
		wrl_output_file.close
	end
	
	def export_stl(stl_output_file)
		cvx = (@dim_x.to_f / 2).to_i # these are the x y and z vertex positions for the "center" fan vertex used to close off the bottom of the model
		cvy =(@dim_y.to_f / 2).to_i
		cvz = 0
		stl_output_file.puts 'solid'
		
		(@dim_y - 1).times {|y| # this loop iterates across all of the relief vertex locations and generates the polygon mesh surface of the model
			(@dim_x - 1).times {|x|
				ax = x
				ay = y
				az = (@daxelspace[x][y][5].to_f / $z_space_divisor_var).to_i
				
				bx = x + 1
				by = y
				bz = (@daxelspace[x + 1][y][5].to_f / $z_space_divisor_var).to_i
				
				cx = x
				cy = y + 1
				cz = (@daxelspace[x][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = y + 1
				dz = (@daxelspace[x + 1][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0'
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0'
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{dx} #{dy} #{dz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
			}
		}	
		
		@dim_x.times {|x| # this loop walks off the top quadrant vertexes writing the curtain and fan for that quadrant
			unless x >= @dim_x - 1
				ax = x # the A and B vertex coordinates are located on the baseline of the model
				ay = 0
				az = 0
				
				bx = x + 1
				by = 0
				bz = 0
				
				cx = x # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = 0
				cz = (@daxelspace[x][0][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = 0
				dz = (@daxelspace[x + 1][0][5].to_f / $z_space_divisor_var).to_i
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly one a,b,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly two b,d,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{dx} #{dy} #{dz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # fan poly cv,b,a
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{cvx} #{cvy} #{cvz}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
			end
		}
		
		@dim_x.times {|x| # this loop walks off the bottom quadrant vertexes writing the curtain and fan for that quadrant
			unless x >= @dim_x - 1
				ax = x # the A and B vertex coordinates are located on the baseline of the model
				ay = @dim_y - 1
				az = 0
				
				bx = x + 1
				by = @dim_y - 1
				bz = 0
				
				cx = x # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = @dim_y - 1
				cz = (@daxelspace[x][@dim_y - 1][5].to_f / $z_space_divisor_var).to_i
				
				dx = x + 1
				dy = @dim_y - 1
				dz = (@daxelspace[x + 1][@dim_y - 1][5].to_f / $z_space_divisor_var).to_i
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly one a,b,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly two b,d,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{dx} #{dy} #{dz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # fan poly cv,b,a
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{cvx} #{cvy} #{cvz}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
			end
		}
		
		@dim_y.times {|y| # this loop walks off the left quadrant vertexes writing the curtain and fan for that quadrant
			unless y >= @dim_y - 1
				ax = 0 # the A and B vertex coordinates are located on the baseline of the model
				ay = y
				az = 0
				
				bx = 0
				by = y + 1
				bz = 0
				
				cx = 0 # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = y
				cz = (@daxelspace[0][y][5].to_f / $z_space_divisor_var).to_i
				
				dx = 0
				dy = y + 1
				dz = (@daxelspace[0][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly one a,b,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly two b,d,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{dx} #{dy} #{dz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # fan poly cv,b,a
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{cvx} #{cvy} #{cvz}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
			end
		}
		
		@dim_y.times {|y| # this loop walks off the right quadrant vertexes writing the curtain and fan for that quadrant
			unless y >= @dim_y - 1
				ax = @dim_x - 1 # the A and B vertex coordinates are located on the baseline of the model
				ay = y
				az = 0
				
				bx = @dim_x - 1
				by = y + 1
				bz = 0
				
				cx = @dim_x - 1 # the C and D vertex coordinates are located on the relief line of the mesh dictated by the displacement map values
				cy = y
				cz = (@daxelspace[@dim_x - 1][y][5].to_f / $z_space_divisor_var).to_i
				
				dx = @dim_x - 1
				dy = y + 1
				dz = (@daxelspace[@dim_x - 1][y + 1][5].to_f / $z_space_divisor_var).to_i
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly one a,b,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # curtain poly two b,d,c
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{dx} #{dy} #{dz}"
				stl_output_file.puts "vertex #{cx} #{cy} #{cz}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
				stl_output_file.puts 'facet normal 0.0 0.0 0.0' # fan poly cv,b,a
				stl_output_file.puts 'outer loop'
				stl_output_file.puts "vertex #{cvx} #{cvy} #{cvz}"
				stl_output_file.puts "vertex #{bx} #{by} #{bz}"
				stl_output_file.puts "vertex #{ax} #{ay} #{az}"
				stl_output_file.puts 'endloop'
				stl_output_file.puts 'endfacet'
				
			end
		}
		
		stl_output_file.puts 'endsolid'
		stl_output_file.close
	end
	
	def kernel_parse(seq_z)
		@dim_y.times {|y|
			@dim_x.times {|x|
			
				reference_pixel = @daxelspace[x][y][1] # this is where we are and what we are comparing too
				samples = [] # these are 2 to 4 samples collected from the surrounding pixel kernel locations
				magnitudes = [] # these are 2 to 4 values representing the difference between the reference pixel and the samples
				mag_ref = 0 # this is the average of the magnitude values
				
				# the sample kernel is a simple cross
				# sample 1 - is 2 pixels up
				unless (y - 1) < 0
					samples << @daxelspace[x][(y - 1)][1]
				end
				# sample 2 - is 2 pixels to the right
				unless (x + 1) > (@dim_x - 1)
					samples << @daxelspace[(x + 1)][y][1]
				end
				
				# sample 3 - is 2 pixels down
				unless (y + 1) > (@dim_y - 1)
					samples << @daxelspace[x][(y + 1)][1]
				end
				
				# sample 4 - is 2 pixels to the left
				unless (x - 1) < 0
					samples << @daxelspace[(x - 1)][y][1]
				end
				
				samples.each {|smp| # this loop iterates over the sample values and populates the magnitude array with absolute difference values between the 
					magnitudes << (smp - reference_pixel).abs
				}
				
				mag_ref = (magnitudes.inject(0){ |sum, el| sum + el }.to_f / magnitudes.size).to_i # this statement iterates over the magnitudes array and creates the average from all of the references present
				mag_ref = mag_ref.abs
				if mag_ref < 1 then
					mag_ref = 0
				end
				
				# daxel_putarray(dx, dy, apos, insert_pos, update_value) 
				$sharpness_daxel_object.daxel_putarray(x, y, 10, 0, mag_ref) # this builds the curve of contrast confidence values in an array this depends on the depth field consisting of 256 images and the focal process moving from closest to farthest point of focus
				
				#if mag_ref >= $sharpness_daxel_object.daxel_getval(x, y, 1) && mag_ref > 0 then # this statement compares the current reference pixels average difference magnitude to the value in the same position in the sharpness daxel and filters out small fluctuations in magnitude
				#	$sharpness_daxel_object.daxel_putval(x, y, 1, mag_ref) # this changes the "g" value to the newly found larger value
				#	$sharpness_daxel_object.daxel_putval(x, y, 5, seq_z) # this changes the "dz" value to the current depth field stack position (its position in the sequence of rgb images)
				#end
			}
		}
	end
	
	def assess_confidence_curve(confidence_threshold)
		
		@dim_y.times {|y|
			@dim_x.times {|x|
				high_confidence_position = 0 # index position along the array / curve where the largest average value was centered
				largest_average_confidence = 0 # running largest value discovered from averaging five values centered on the current index
				@daxelspace[x][y][10].length.times do |indexval| # iterate over this pixels depth field curve array
					samples = [] # make a new empty array to hold the sample window of values
					
					unless (indexval - 3) < 0 # collect the values in front of and behind the current index 
						samples << @daxelspace[x][y][10][indexval - 3]
					end
					
					unless (indexval - 2) < 0
						samples << @daxelspace[x][y][10][indexval - 2]
					end
					
					unless (indexval - 1) < 0
						samples << @daxelspace[x][y][10][indexval - 1]
					end
					
					samples << @daxelspace[x][y][10][indexval]
					
					unless (indexval + 1) > (@daxelspace[x][y][10].length - 1)
						samples << @daxelspace[x][y][10][indexval + 1]
					end
					
					unless (indexval + 2) > (@daxelspace[x][y][10].length - 1)
						samples << @daxelspace[x][y][10][indexval + 2]
					end
					
					unless (indexval + 3) > (@daxelspace[x][y][10].length - 1)
						samples << @daxelspace[x][y][10][indexval + 3]
					end
					
					samples.sort! # sort the samples in ascending order
					samples.pop # remove the largest value found in the sorted set in the hopes of eliminating a chaotic outlier
					current_average_confidence = (samples.inject(0){ |sum, el| sum + el }.to_f / samples.size).to_i # find the average of the remaining sample values
					current_average_confidence = current_average_confidence.abs
					if current_average_confidence > largest_average_confidence && current_average_confidence > confidence_threshold.to_i then
						largest_average_confidence = current_average_confidence
						high_confidence_position = indexval
					end
				end
				
				@daxelspace[x][y][1] = largest_average_confidence
				@daxelspace[x][y][5] = high_confidence_position
			}
		}
	end
	
	def infill(grid_filter) # this function walks over the pixel grid and finds zero values left behind by a failure to meet confidence value threshholds these zeros are then filled by an average of any adjacent non zero pixel values this function loops untill all zero values are filled 
		
		@dim_y.times {|y|
		
			if grid_filter == 1 || grid_filter == 3 then
				if y.even? == true then
					next
				end
			end
			
			if grid_filter == 2 || grid_filter == 4 then
				if y.odd? == true then
					next
				end
			end
			
			@dim_x.times {|x|
			
				if grid_filter == 1 || grid_filter == 4 then
					if x.even? == true then
						next
					end
				end
			
				if grid_filter == 2 || grid_filter == 3 then
					if x.odd? == true then
						next
					end
				end
			
				if @daxelspace[x][y][5] == 0 then
					$found_zero_value = true
					samples = []
					
					unless (x - 1) < 0 || (y - 1) < 0 # as per a keyboard number pad this pixel is in position 7, the current pixel would of course be position 5
						unless @daxelspace[x - 1][y - 1][5] == 0
							samples << @daxelspace[x - 1][y - 1][5]
						end
					end
					
					unless (y - 1) < 0 # num pad 8
						unless @daxelspace[x][y - 1][5] == 0
							samples << @daxelspace[x][y - 1][5]
						end
					end
					
					unless (y - 1) < 0 || @daxelspace[x + 1] == nil # num pad 9
						unless @daxelspace[x + 1][y - 1][5] == 0
							samples << @daxelspace[x + 1][y - 1][5]
						end
					end
					
					unless (x - 1) < 0 # num pad 4
						unless @daxelspace[x - 1][y][5] == 0
							samples << @daxelspace[x - 1][y][5]
						end
					end
					
					unless @daxelspace[x + 1] == nil # num pad 6
						unless @daxelspace[x + 1][y][5] == 0
							samples << @daxelspace[x + 1][y][5]
						end
					end
					
					unless (x - 1) < 0 || @daxelspace[x][y + 1] == nil # num pad 1
						unless @daxelspace[x - 1][y + 1][5] == 0
							samples << @daxelspace[x - 1][y + 1][5]
						end
					end
					
					unless @daxelspace[x][y + 1] == nil # num pad 2
						unless @daxelspace[x][y + 1][5] == 0
							samples << @daxelspace[x][y + 1][5]
						end
					end
					
					unless @daxelspace[x + 1] == nil || @daxelspace[x][y + 1] == nil # num pad 3
						unless @daxelspace[x + 1][y + 1][5] == 0
							samples << @daxelspace[x + 1][y + 1][5]
						end
					end
					
					unless samples.empty? == true
						sample_average = (samples.inject(0){ |sum, el| sum + el }.to_f / samples.size).to_i
						if sample_average < 1 then
							sample_average = 1
						end
						@daxelspace[x][y][5] = sample_average
					end
				end
			}
		}
	end
	
	def median_filter(kernel_radius, arr_pos_eval, arr_pos_write) # kernel_radius is the distance in pixels away from the current pixel the kernel will cover (a value of 1 = 3x3, 2 = 5x5), arr_pos_eval is the daxel array index value that will be analysed, arr_pos_write is the daxel array index value that will receive the processed value ()
	
	end
end



#--------------------------------------------------------------------------
# end of class functions
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# program functions

def select_rawfile()
	$rawfile = Tk.getOpenFile
	patharray = $rawfile.split("\/")
	$selected_rawfile_name.value = patharray.last
end

def select_h_map_rawfile()
	$h_map_rawfile = Tk.getOpenFile
	patharray = $h_map_rawfile.split("\/")
	$selected_h_map_rawfile_name.value = patharray.last
end

def select_savefile()
	$savefile = Tk.getSaveFile
	patharray = $savefile.split("\/")
	$selected_savefile_name.value = patharray.last
	$output_obj = File.open($savefile, "a") # this is the name and extention of the obj file the resultant mesh will be exported too
end

def dump_to_file(dfile, data)
	File.open(dfile, "w") do |file|
		data.each {|value|
		file.puts value
		puts value # to $STDOUT
		}
		file.close
	end
end


def process_chromakey()
	Find.find("#{$gs_files_dir.value}") do |ckfile| # open every .tif file in the directory
		@ckfile = ckfile.to_s
		if @ckfile[-3, 3] == "tif" then
			patharray = @ckfile.split("\/")
			savefile_name = (patharray.last).to_s
			savefile_name = $gs_processed_files_dir + "\\" + savefile_name
			system("convert #{@ckfile} -channel #{$channel_mask_val} -separate +channel -fuzz #{$tolerance_fuzz_val}% -fill black -opaque black -fill white +opaque black -morphology Dilate:#{$apply_times} Square -negate screen_mask.tif")
			#sleep(2)
			system("composite #{@ckfile} -size #{$img_x_width}x#{$img_y_height} xc:black comp.tif screen_mask.tif +matte #{savefile_name}")
		end
	end
end

def convert_jpg_to_rgb_raw()
	Find.find("#{$seq_in_directory.value}") do |dffile| # open every file in the directory
		@dffile = dffile.to_s
		if @dffile[-3, 3] == "JPG" || @dffile[-3, 3] == "jpg" || @dffile[-3, 3] == "DNG" || @dffile[-3, 3] == "dng" then # check if it is a jpeg or a dng camera raw file file
			patharray = @dffile.split("\/") # split the path and filename string on the "/" and turn it into array entries
			savefile_name = (patharray.last).to_s # get the last entry in the array the filename and extention
			savefile_array = savefile_name.split(".") # split filename and extention into an array on the "."
			savefile_name_b = "#{$seq_out_directory.value}" + "\\" + savefile_array[0].to_s + ".rgb" # concatenate all parts of the new savefile name and location with the new extention that will tell imagemagick what to convert the jpeg file into in this case the no-frills raw format .rgb
			system("convert #{@dffile} -resize 640x480! #{savefile_name_b}") # imagemagick system call that does the size normalization and conversion
		end
	end
end

def parse_each_depth_field()
	Find.find("#{$seq_out_directory.value}") do |rgbfile| # open every file in the directory
		@rgbfile = rgbfile.to_s
		$seq_ref = $seq_ref - 1
		if $seq_ref < 1 then
			$seq_ref = 1
		end
		if @rgbfile[-3, 3] == "RGB" || @rgbfile[-3, 3] == "rgb" then # check if it is a .rgb file
			$a_depth_field_daxel = Daxelject.new($img_x_width, $img_y_height, @rgbfile) # make a new daxel object with the current iterations rgb file
			$a_depth_field_daxel.form
			$a_depth_field_daxel.fill
			$a_depth_field_daxel.kernel_parse($seq_ref)
		end
	end
end

#--------------------------------------------------------------------------
#---EXPORT BUTTONS---------------------------------------------------------
#--------------------------------------------------------------------------

def makemesh()
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	$a_daxel_object.enumerate_vertex_list($output_obj)
	$a_daxel_object.enumerate_surface_polygons($output_obj)
end

def render_iso_relief(bg_r, bg_g, bg_b, iso_z)
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	if $transpose_z == "transpose z"
		$a_daxel_object.transpose_z_values
	end
	$a_daxel_object.render_image_svg($output_obj)
end

def render_landscape_transform()
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	if $histomap == "histomap"
		$h_map_daxel_object = Daxelject.new($img_x_width, $img_y_height, $h_map_rawfile)
		$h_map_daxel_object.form
		$h_map_daxel_object.fill
		$a_daxel_object.impose_histomap(1, $h_map_daxel_object) # impose_histomap(daxel array position for source R G or B value, a height map daxel object) - in this case (1, $h_map_daxel_object) will use the "g" values from $h_map_daxel_object
	end	
	if $transpose_z == "transpose z"
		$a_daxel_object.transpose_z_values
	end
	$a_daxel_object.explicate_iso_offsets
	$a_daxel_object.bbox_coordinates
	$a_daxel_object.render_landscape_svg($output_obj)
end

def render_x_three_d()
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	if $histomap == "histomap"
		$h_map_daxel_object = Daxelject.new($img_x_width, $img_y_height, $h_map_rawfile)
		$h_map_daxel_object.form
		$h_map_daxel_object.fill
		$a_daxel_object.impose_histomap(1, $h_map_daxel_object) # impose_histomap(daxel array position for source R G or B value, a height map daxel object) - in this case (1, $h_map_daxel_object) will use the "g" values from $h_map_daxel_object
	end	
	if $transpose_z == "transpose z"
		$a_daxel_object.transpose_z_values
	end
	$a_daxel_object.export_x_three_d($output_obj)
end

def render_wrl()
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	if $histomap == "histomap"
		$h_map_daxel_object = Daxelject.new($img_x_width, $img_y_height, $h_map_rawfile)
		$h_map_daxel_object.form
		$h_map_daxel_object.fill
		$a_daxel_object.impose_histomap(1, $h_map_daxel_object) # impose_histomap(daxel array position for source R G or B value, a height map daxel object) - in this case (1, $h_map_daxel_object) will use the "g" values from $h_map_daxel_object
	end	
	if $transpose_z == "transpose z"
		$a_daxel_object.transpose_z_values
	end
	$a_daxel_object.export_wrl($output_obj)
end

def render_stl()
	$a_daxel_object = Daxelject.new($img_x_width, $img_y_height, $h_map_rawfile)
	$a_daxel_object.form
	$a_daxel_object.fill
	$a_daxel_object.relief("g")
	if $histomap == "histomap"
		$h_map_daxel_object = Daxelject.new($img_x_width, $img_y_height, $h_map_rawfile)
		$h_map_daxel_object.form
		$h_map_daxel_object.fill
		$a_daxel_object.impose_histomap(1, $h_map_daxel_object) # impose_histomap(daxel array position for source R G or B value, a height map daxel object) - in this case (1, $h_map_daxel_object) will use the "g" values from $h_map_daxel_object
	end	
	if $transpose_z == "transpose z"
		$a_daxel_object.transpose_z_values
	end
	$a_daxel_object.export_stl($output_obj)
end

def adjust_projection_visualizer()
	$vis_clear = TkcRectangle.new($projection_visualizer, 0, 0, 220, 120, 'fill' => "grey")
	$pvl_one = TkcLine.new($projection_visualizer, 5, 5, (100 + 5), 5, 'width' => 2, 'dash' => "-", 'fill' => 'violet', 'capstyle' => "round")
	$pvl_two = TkcLine.new($projection_visualizer, (5 + $skew), ((5 + 100) - $tilt), ((100 + 5) + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'violet', 'capstyle' => "round")
	$pvl_three = TkcLine.new($projection_visualizer, 5, 5, (5 + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'green', 'capstyle' => "round")
	$pvl_four = TkcLine.new($projection_visualizer, (100 + 5), 5, ((100 + 5) + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'green', 'capstyle' => "round")
end

def adjust_ap_visualizer()
	$ap_vis_clear = TkcRectangle.new($ap_visualizer, 0, 0, 100, 100, 'fill' => "grey")
	$apa_one = TkcArc.new($ap_visualizer, ($ap_focus_x - $falloff), ($ap_focus_y - $falloff), ($ap_focus_x + $falloff), ($ap_focus_y + $falloff), 'width' => 1, 'dash' => ".", 'style' => 'arc', 'extent' => 359, 'outline' => "white")
	$apl_one = TkcLine.new($ap_visualizer, $ap_focus_x, $ap_focus_y, $ap_focus_x, $ap_focus_y, 'width' => 4, 'fill' => 'green', 'capstyle' => "round")
end

def process_depth_field()
	convert_jpg_to_rgb_raw()
	$sharpness_daxel_object = Daxelject.new($img_x_width, $img_y_height, "C:\\testing\\cps\\sharpness_baseline.raw") # this creates the daxel object that will hold the depth field sequence positions of the sharpest pixels found across all of the sequence images analyzed
	$sharpness_daxel_object.form
	$sharpness_daxel_object.fill
	$sharpness_daxel_object.change_all_at(5, 0) # change_all_at will replace all values in the daxel data array at the position specified with the value given, in this case changing all "z" values to 0
	parse_each_depth_field()
	$sharpness_daxel_object.assess_confidence_curve($conf_thresh.value) # 
	loop do
		$found_zero_value = false
		$sharpness_daxel_object.infill(1) # even, even x y positions are skipped
		$sharpness_daxel_object.infill(3) # odd, odd x y positions are skipped
		$sharpness_daxel_object.infill(2) # even, odd x y positions are skipped
		$sharpness_daxel_object.infill(4) # odd, even x y positions are skipped
		$sharpness_daxel_object.infill(3) # even, even x y positions are skipped
		$sharpness_daxel_object.infill(4) # odd, odd x y positions are skipped
		$sharpness_daxel_object.infill(1) # even, odd x y positions are skipped
		$sharpness_daxel_object.infill(2) # odd, even x y positions are skipped
		break if $found_zero_value == false
	end
	# $sharpness_daxel_object.median_filter()
	$sharpness_daxel_object.pack_disp_rgb($output_obj)
	$sharpness_daxel_object.pack_confidence_map_rgb("C:\\testing\\cps\\confidence_map.raw")
end

#--------------------------------------------------------------------------
# end of program functions
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# SETUP 2

$hex_dim_one = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"] # establish two arrays with a list of base 16 char values
$hex_dim_two = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]

$hex_dim_one.each {|d1| # itterate over a nested loop to create all of the base 16 value pairs
	$hex_dim_two.each {|d2|
		$hex_lookup << "#{d1}#{d2}" # once populated the index of the $hex_lookup array will corrolate to its value as along an 8-bit color channel, ie. index 0 = "00", and index 255 = "ff"
	}
}

#--------------------------------------------------------------------------
# GUI 

# Formatting Presets
pnav = {'side'=>'top', 'padx'=>5, 'pady'=>5}
pFstfb = {'side'=>'top', 'fill'=>'both'}
pBsrxy = {'side'=>'right', 'padx'=>5, 'pady'=>5}
pLsbxy = {'side'=>'bottom', 'padx'=>5, 'pady'=>5}

# FRAME TREE
# TkRoot
#	$appframe
#		modeframe
#			img_to_relief_mode
#				image_set_x_frame
#				image_set_y_frame
#		settingsframe
#			setbox_one
#				setbox_one_a
#			setbox_projection
#			setbox_ap
#			setbox_depth_field


# appframe\
$appframe = TkRoot.new('title'=>"Daxelject, RAW file to complex plane data visualizer", 'geometry'=>('+200+200'))
$appframe.minsize(800, 600)

# appframe\modeframe
modeframe = TkFrame.new($appframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'left', 'fill'=>'both')

# appframe\modeframe\img_to_relief_mode
img_to_relief_mode = TkFrame.new(modeframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'left', 'fill'=>'both')
TkLabel.new(img_to_relief_mode, 'text'=>"File", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$select_single_rawfile = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 normal')
	text "Select rawfile"
	command proc {select_rawfile}
	height 1
	width 18
	pack(pnav)
end
$display_selected_rawfile = TkLabel.new(img_to_relief_mode, 'textvariable'=>$selected_rawfile_name, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

$select_single_h_map_rawfile = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 normal')
	text "Use height map"
	command proc {select_h_map_rawfile}
	height 1
	width 18
	pack(pnav)
end
$display_selected_h_map_rawfile = TkLabel.new(img_to_relief_mode, 'textvariable'=>$selected_h_map_rawfile_name, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

$select_save_location = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 normal')
	text "initiate savefile"
	command proc {select_savefile}
	height 1
	width 18
	pack(pnav)
end
$display_selected_savefile = TkLabel.new(img_to_relief_mode, 'textvariable'=>$selected_savefile_name, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

# appframe\modeframe\img_to_relief_mode\image_set_x_frame
image_set_x_frame = TkFrame.new(img_to_relief_mode, 'relief'=>'solid', 'borderwidth'=>1, 'background'=>'grey').pack('side'=>'top', 'fill'=>'both')
TkLabel.new(image_set_x_frame, 'text'=>"Enter rawfile X length in pixels", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(image_set_x_frame, 'textvariable'=>$img_x_width, 'width'=>10, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)
# appframe\modeframe\img_to_relief_mode\image_set_y_frame
image_set_y_frame = TkFrame.new(img_to_relief_mode, 'relief'=>'solid', 'borderwidth'=>1, 'background'=>'grey').pack('side'=>'top', 'fill'=>'both')
TkLabel.new(image_set_y_frame, 'text'=>"Enter rawfile Y height in pixels", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(image_set_y_frame, 'textvariable'=>$img_y_height, 'width'=>10, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)

TkLabel.new(img_to_relief_mode, 'text'=>"Process", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$call_make_mesh = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "MAKE A MESH!"
	fg "blue2"
	command proc {makemesh}
	height 2
	width 18
	pack(pnav)
end

$call_iso_render = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "RENDER SVG\nISOMETRIC RELIEF"
	fg "blue2"
	command proc {render_iso_relief(0, 0, 0, 256)} # 
	height 3
	width 18
	pack(pnav)
end

$call_landscape_transform_render = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "RENDER SVG\nLANDSCAPE\nTRANSFORM"
	fg "blue2"
	command proc {render_landscape_transform} # 
	height 4
	width 18
	pack(pnav)
end

$call_x_three_d_render = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "RENDER TO\nX3D\nPOINTCLOUD"
	fg "blue2"
	command proc {render_x_three_d} # 
	height 4
	width 18
	pack(pnav)
end

$call_stl_render = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "RENDER TO\nSTL"
	fg "blue2"
	command proc {render_stl} # 
	height 3
	width 18
	pack(pnav)
end

$call_wrl_render = TkButton.new(img_to_relief_mode) do
	font TkFont.new('arial 8 bold')
	text "RENDER TO\nWRL\nCLOSED MESH"
	fg "blue2"
	command proc {render_wrl} # 
	height 4
	width 18
	pack(pnav)
end

#--------------------------------------------------------------------------
# appframe\settingsframe
settingsframe = TkFrame.new($appframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'left', 'fill'=>'both')
# appframe\settingsframe\setbox_one
setbox_one = TkFrame.new(settingsframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'left', 'fill'=>'both')
TkLabel.new(setbox_one, 'text'=>"Settings", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

TkLabel.new(setbox_one, 'text'=>"Bg Hex Val", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(setbox_one, 'textvariable'=>$bg_hex, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)

TkLabel.new(setbox_one, 'text'=>"Z Depth", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(setbox_one, 'textvariable'=>$zdepth_var, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)

TkLabel.new(setbox_one, 'text'=>"Z Space Divisor", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(setbox_one, 'textvariable'=>$z_space_divisor_var, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)

TkLabel.new(setbox_one, 'text'=>"Grid Sections", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(setbox_one, 'textvariable'=>$grid_sections_var, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)


$points_lines_toggle = TkCheckButton.new(setbox_one) do
	textvariable $svg_render_style
	height 2
	width 10
	# bg 'grey'
	variable $svg_render_style
	onvalue 'points'
	offvalue 'lines'
	place('height'=>25, 'width'=>100, 'x'=>0, 'y'=>50)
end

$transpose_z_toggle = TkCheckButton.new(setbox_one) do
	textvariable $transpose_z
	height 2
	width 10
	# bg 'grey'
	variable $transpose_z
	onvalue 'transpose z'
	offvalue 'natural z'
	place('height'=>25, 'width'=>100, 'x'=>0, 'y'=>75)
end

$histomap_toggle = TkCheckButton.new(setbox_one) do
	textvariable $histomap
	height 2
	width 10
	# bg 'grey'
	variable $histomap
	onvalue 'histomap'
	offvalue 'no histomap'
	place('height'=>25, 'width'=>100, 'x'=>0, 'y'=>100)
end


# -------------------------------------------------------------------------------------------------------------------------------
# Chromakey processing controls
# -------------------------------------------------------------------------------------------------------------------------------
# appframe\settingsframe\setbox_one\set_box_one_a
setbox_one_a = TkFrame.new(setbox_one, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'bottom', 'fill'=>'both')

TkLabel.new(setbox_one_a, 'text'=>"Chroma_Key Processing", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$select_gs_dir = TkButton.new(setbox_one_a) do
	font TkFont.new('arial 8 normal')
	text "Select chromakey matted\nfiles location"
	command proc {$gs_files_dir.value = Tk.chooseDirectory}
	height 2
	width 22
	pack('side'=>'top', 'padx'=>5, 'pady'=>5)
end
$display_selected_gs_files_dir = TkLabel.new(setbox_one_a, 'textvariable'=>$gs_files_dir, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

$select_gs_processed_dir = TkButton.new(setbox_one_a) do
	font TkFont.new('arial 8 normal')
	text "Select save location\nfor processed files"
	command proc {$gs_processed_files_dir.value = Tk.chooseDirectory}
	height 2
	width 22
	pack('side'=>'top', 'padx'=>5, 'pady'=>5)
end
$display_processed_gs_files_dir = TkLabel.new(setbox_one_a, 'textvariable'=>$gs_processed_files_dir, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

	
TkLabel.new(setbox_one_a, 'text'=>"mask color channel", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack('side'=>'top', 'padx'=>5, 'pady'=>5)
TkEntry.new(setbox_one_a, 'textvariable'=>$channel_mask_val, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack('side'=>'top', 'padx'=>5, 'pady'=>5)
	
TkLabel.new(setbox_one_a, 'text'=>"chroma tolerance %", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack('side'=>'top', 'padx'=>5, 'pady'=>5)
TkEntry.new(setbox_one_a, 'textvariable'=>$tolerance_fuzz_val, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack('side'=>'top', 'padx'=>5, 'pady'=>5)

TkLabel.new(setbox_one_a, 'text'=>"mask dilation iterations", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack('side'=>'top', 'padx'=>5, 'pady'=>5)
TkEntry.new(setbox_one_a, 'textvariable'=>$apply_times, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack('side'=>'top', 'padx'=>5, 'pady'=>5)

$call_process_gs_toplevel = TkButton.new(setbox_one_a) do
	font TkFont.new('arial 8 bold')
	text "Process Out\nChromakey"
	fg "blue2"
	command proc {process_chromakey} # 
	height 3
	width 18
	pack(pnav)
end
# -------------------------------------------------------------------------------------------------------------------------------


# appframe\settingsframe\setbox_projection
setbox_projection = TkFrame.new(settingsframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'top', 'fill'=>'x')

TkLabel.new(setbox_projection, 'text'=>"Adjust Landscape Transformation Values", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$projection_visualizer = TkCanvas.new(setbox_projection) do
	place('height' => 120, 'width' => 220, 'x' => 10, 'y' => 40)
end

$tilt_y_scale = TkScale.new(setbox_projection) do
	orient 'vertical'
	label 'Tilt %'
	bg 'grey'
	length 220 # scale widget footprint
	width 10
	sliderlength 10 # slider handle size
	from 100
	to 0
	variable $tilt
	command proc {adjust_projection_visualizer}
	tickinterval 20
	pack('side'=>'right')
end

$skew_x_scale = TkScale.new(setbox_projection) do
	orient 'horizontal'
	label 'Skew %'
	bg 'grey'
	length 240 # scale widget footprint
	width 10
	sliderlength 10 # slider handle size
	from 0
	to 100
	variable $skew
	command proc {adjust_projection_visualizer}
	tickinterval 20
	pack('side'=>'bottom', 'fill'=>'x')
end


$vis_clear = TkcRectangle.new($projection_visualizer, 0, 0, 220, 120, 'fill' => "grey")
$pvl_one = TkcLine.new($projection_visualizer, 5, 5, (100 + 5), 5, 'width' => 2, 'dash' => "-", 'fill' => 'violet', 'capstyle' => "round")
$pvl_two = TkcLine.new($projection_visualizer, (5 + $skew), ((5 + 100) - $tilt), ((100 + 5) + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'violet', 'capstyle' => "round")
$pvl_three = TkcLine.new($projection_visualizer, 5, 5, (5 + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'green', 'capstyle' => "round")
$pvl_four = TkcLine.new($projection_visualizer, (100 + 5), 5, ((100 + 5) + $skew), ((5 + 100) - $tilt), 'width' => 2, 'dash' => "-", 'fill' => 'green', 'capstyle' => "round")

# appframe\settingsframe\setbox_ap
setbox_ap = TkFrame.new(settingsframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'top', 'fill'=>'x')

TkLabel.new(setbox_ap, 'text'=>"Adjust Atmosphearic Perspective Values", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$ap_visualizer = TkCanvas.new(setbox_ap) do
	place('height' => 100, 'width' => 100, 'x' => 70, 'y' => 40)
end
$ap_visualizer.bind('1', proc{|apv| $ap_focus_x = apv.x;
	$ap_focus_y = apv.y;
	adjust_ap_visualizer})

$falloff_scale = TkScale.new(setbox_ap) do
	orient 'vertical'
	label 'falloff'
	bg 'grey'
	length 120 # scale widget footprint
	width 10
	sliderlength 10 # slider handle size
	from 0
	to 50
	variable $falloff
	command proc {adjust_ap_visualizer}
	tickinterval 10
	pack('side'=>'right', 'fill'=>'y')
end

$ap_render_toggle = TkCheckButton.new(setbox_ap) do
	textvariable $ap_render
	height 2
	width 10
	# bg 'grey'
	variable $ap_render
	onvalue 'on'
	offvalue 'off'
	place('height'=>25, 'width'=>60, 'x'=>0, 'y'=>125)
end


# appframe\settingsframe\setbox_depth_field
setbox_depth_field = TkFrame.new(settingsframe, 'relief'=>'groove', 'borderwidth'=>3, 'background'=>'grey').pack('side'=>'top', 'fill'=>'x')

TkLabel.new(setbox_depth_field, 'text'=>"Depth Field Processing", 'font'=>$headerfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)

$select_df_dir = TkButton.new(setbox_depth_field) do
	font TkFont.new('arial 8 normal')
	text "Select Depth Field\nfiles location"
	command proc {$seq_in_directory.value = Tk.chooseDirectory}
	height 2
	width 22
	pack('side'=>'top', 'padx'=>5, 'pady'=>5)
end
$display_selected_df_files_dir = TkLabel.new(setbox_depth_field, 'textvariable'=>$seq_in_directory, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

$select_df_processed_dir = TkButton.new(setbox_depth_field) do
	font TkFont.new('arial 8 normal')
	text "Select save location\nfor processed files"
	command proc {$seq_out_directory.value = Tk.chooseDirectory}
	height 2
	width 22
	pack('side'=>'top', 'padx'=>5, 'pady'=>5)
end
$display_processed_df_files_dir = TkLabel.new(setbox_depth_field, 'textvariable'=>$seq_out_directory, 'relief'=>'sunken', 'font'=>$displayfont, 'width'=>25, 'bg'=>'gray55', 'foreground'=>'cyan').pack(pnav)

TkLabel.new(setbox_depth_field, 'text'=>"Confidence Threshold", 'font'=>$displayfont, 'width'=>38, 'bg'=>'grey', 'foreground'=>'mediumorchid4').pack(pnav)
TkEntry.new(setbox_depth_field, 'textvariable'=>$conf_thresh, 'width'=>7, 'bg'=>'white', 'foreground'=>'dark slate gray').pack(pnav)

$call_process_df_toplevel = TkButton.new(setbox_depth_field) do
	font TkFont.new('arial 8 bold')
	text "Process\nHeight Map from\nDepth Field Images"
	fg "blue2"
	command proc {process_depth_field} # 
	height 4
	width 22
	pack(pnav)
end

# AP adjustment display elements
$ap_vis_clear = TkcRectangle.new($ap_visualizer, 0, 0, 100, 100, 'fill' => "grey")
$apa_one = TkcArc.new($ap_visualizer, 0, 0, 100, 100, 'width' => 1, 'dash' => ".", 'style' => 'arc', 'extent' => 359, 'outline' => "white")
$apl_one = TkcLine.new($ap_visualizer, 50, 50, 50, 50, 'width' => 4, 'fill' => 'green', 'capstyle' => "round")


# Call Tk main loop
Tk.mainloop
