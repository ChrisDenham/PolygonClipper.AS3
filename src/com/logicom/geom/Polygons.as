package com.logicom.geom 
{
	public class Polygons
	{
		public function Polygons() 
		{		
		}
		
		public function addPolygon(polygon:Polygon):void
		{
			_polygons.push(polygon);
		}
		
		public function clear():void
		{
			_polygons.length = 0;
		}
		
		public function getPolygons():Vector.<Polygon>
		{
			return _polygons;
		}
		
		private var _polygons:Vector.<Polygon> = new Vector.<Polygon>();
	}
}