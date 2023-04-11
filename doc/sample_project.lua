vast:setup({
	DataSource={
		class=ConnectorUDP,
		port=1254,
		ip="0.152.12.48",
		channels={
			event={
				type="int",
				size=4,
				count=1,
			},
			position={
				type="double",
				size=8,
				count=3,
			},
			attitude={
				type="double",
				size=8,
				count=3,
			},
		},
	},
	Views={
		MinimapView={
			class=Minimap,
			projection=Merkator,
			pos_in_percent={0,0},
			size_in_percent={10, 10},
			visible=false,
			targets={
				{
					target=rocket_Model,
					color={255,255,0},
				},
			},
		},
		GlobeView={
			class=View,
			pos_in_percent={10,0}, -- or pos_in_pixel
			size_in_pixel={200, 300},
			visible=false,
			childs={
				earth_light_model={
					class=Earth,
					highdef=false,
					sky_layers={
						Clouds_Layer,
					},
				},
				tracker_model={
					class=Tracker,
					primitve_type=line,
					thickness=3.0,
					targets={
						{
							target=rocket_Model,
							color={255,255,0},
						},
						{
							target=satellite_Model,
							color={255,0,255},
						},
					}
				}
			},
			Cameras={
				camera1={
					class=CameraFixed,
					pos={0,-1e5,0},
					dir={0,1,0},
					target=earth_light_model,
				},
				active=camera1,
			},
		},
		RocketView={
			class=View,
			pos_in_percent={50,0}, 
			size_in_pixel={200, 300},
			visible=true,
			childs={
				launchpad_model={
					class=Avatar,
					pos={0,0,0},
					lla={0,0,0}, -- Lattitude, Longitude, Altitude
					rot={0,0,0},
					events={
						[8]=function() end,
						[60]=function() end,
					},
					childs={
						cubemap_Ground_Close={
							class=CubeMap,
							picture="cubempa_ground_close.png",
						},
						cubemap_Ground_Far={
							class=CubeMap,
							picture="cubempa_ground_far.png",
						},
						launchpad_Model={
							class=Avatar,
							pos={0,0,0},
							rot={0,0,0},
							model=scene_launchpad.tscn,
							events={
								[52]=function() end,
								[63]=function() end,
							},
						},
					},
				},
				rocket_Model={
					class=Avatar,
					pos={0,0,0},
					rot={0,0,0},
					events={
						[5]=function() end,
						[6]=function() end,
					},
					childs={
						etage1_Model={
							class=Avatar,
							pos={0,0,100}, -- relative to parent
							rot={0,0,0},
							model=scene_etage1.tscn,
							events={
								[0]=function() end,
								[2]=function() end,
								[156]=function() end,
							},
							childs={
								reactor1_Model={
									class=Avatar,
									pos={20,0,0},
									rot={0,0,0},
									model=scene_reactor.tscn,
									events={
										[121]=function() end, -- allumage 
										[122]=function() end, -- decrochage
									},
								},
								reactor2_Model={
									class=Avatar,
									pos={-20,0,0},
									rot={0,0,0},
									model=scene_reactor.tscn,
									events={
										[123]=function() end, -- allumage 
										[124]=function() end, -- decrochage
									},
								}
							}
						},
						etage2_Model={
							class=Avatar,
							pos={0,0,200}, -- relative to parent
							rot={0,0,0},
							model=scene_etage2.tscn,
							events={
								[1]=function() end,
								[3]=function() end,
								[6]=function() end,
							},
						},
						etage3_Model={
							class=Avatar,
							pos={0,0,300}, -- relative to parent
							rot={0,0,0},
							model=scene_etage3.tscn,
							events={
								[1]=function() end,
								[2]=function() end,
							},
						},
						satellite_Model={
							class=Avatar,
							pos={0,0,320}, -- relative to parent
							rot={0,0,0},
							model=scene_satellite_1.tscn,
							events={
								[10]=function() end,
								[25]=function() end,
							},
						},
					},
				},
				Earth_Model={
					class=Earth,
					highdef=true,
					sky_layers={
						--Clouds_Layer,
						Stellar_Layer={
							class=Stellar,
							visible=false,
						},
					},
				},
				widget_background={
					class=texture,
					pos={0,0},
					size={100,100%},
					visible=true,
					level=foreground,
				}
			},
			Cameras={
				--[[
				camera_launchpad={
					class=CameraFixed,
					pos={0,-1e5,0},
					dir={0,1,0},
					target=launchpad_model,
					events={
						[80]=function() end, -- genre event_init
					},
				},
				]]
				camera_rocket={
					class=CameraTrackball,
					name="camera_rocket",
					target=rocket_Model,
					rot={0,0,0},
					up_vector={0,0,1},
					distance=100,
					events={
						[81]=function() end, -- genre event_start
					},
				},
				camera_earth={
					class=CameraFixed,
					pos={0,-1e5,0},
					dir={0,1,0},
					target=Earth_Model,
					events={
						[82]=function() end,-- genre event_altitude_6500km
					},
				},
				active=camera_launchpad,
				events={
					[83]=function() end,
				},
			},
			Widgets={
				Button_Quit={
					class=Button,
					pos_in_percent={50,0}, 
					size={100, 300%}, --il faudrait comme en css pouvoir mettre du % ou du pixel
					on_pressed=function() end,
					on_released=function() end
				}
			}
		},
		WidgetView={
			class=IHM,
			pos_in_pixel={50,0}, 
			size_in_pixel={200, 300},
			visible=true,
			Widgets={
				CheckBox_Infos={
					class=Button,
					pos_in_percent={50,0}, 
					size={100, 300%}, --il faudrait comme en css pouvoir mettre du % ou du pixel
					on_mouse_pressed=function(button_id) end,
					on_mouse_released=function(button_id) end,
					on_key_pressed=function(key_id) end,
					on_key_released=function(key_id) end,
				},
				Infos_Text={
					class=TestBlock,
					size={100, 100%}, 
					visible=false,
					on_update=function() end,
				},
			},
		},
	},
	--[[
		Events={
			{
				[0]="AllumageEtage1",
				[1]="ArretEtage1",
				[2]="SeparationEtage1",
				[3]="AllumageEtage2",
				[4]="ArretEtage2",
				[5]="SeparationEtage2",
				[6]="AllumageEtage3",
				[7]="ArretEtage3",
				[8]="EjectionCoiffePartie1",
				[9]="EjectionCoiffePartie2",
			},
			bind=function(event_id, event_name) end
		},
	]]
},)

function init()
	local rocket_view = vast:getViews("RocketView");
	if rocket_view ~= nil then
		rocket_view.setVisible(true);
		rocket_view.setActiveCamera("camera_rocket");
	end
end

function start(vast_instance)

end

function step(vast_instance)

end

vast:set_init_hook(init)
vast:set_start_hook(start)
vast:set_step_hook(step)

vast:init()
vast:start()
