Parse.Cloud.define("getMap", function(request, response) {
	var building = request.params.building;
	var floor = request.params.floor;

	//console.log("building: " + building);
	//console.log("floor: " + floor);

	var mapQuery = new Parse.Query("Map");
	mapQuery.equalTo("building", building);
	mapQuery.equalTo("floor", floor);

	mapQuery.first({
		success: function(map) {
			//console.log("Map: " + map);
			var mapRegionsQuery = new Parse.Query("MapRegion");
			mapRegionsQuery.equalTo("map", map);
			mapRegionsQuery.find({
				success: function(regions) {
					if (regions.length == 0) {
						response.error("No map regions defined");
						return;
					}

					response.success({
						"bearing" : map.get("bearing"),
						"mapImage" : map.get("mapImage"),
						"regions" : regions
					});
				},
				error: function(error) {
					response.error(error.message);
				}
			});
		},
		error: function(error) {
			response.error(error.message);
		}
	});

});
