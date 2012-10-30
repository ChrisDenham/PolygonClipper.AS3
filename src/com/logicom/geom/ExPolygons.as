package com.logicom.geom 
{
	public class ExPolygons extends Array
	{
		public function ExPolygons() 
		{		
		}
		
		public function addExPolygon(exPolygon:ExPolygon):void
		{
			push(exPolygon);
		}				
	}
}