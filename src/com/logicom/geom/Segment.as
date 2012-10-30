package com.logicom.geom 
{
	public class Segment 
	{
		public function Segment(pt1:IntPoint, pt2:IntPoint) 
		{
			this.pt1 = pt1;
			this.pt2 = pt2;
		}
		
		public function swapPoints():void
		{
			var temp:IntPoint = pt1;
			pt1 = pt2;
			pt2 = temp;
		}
		
		public var pt1:IntPoint;
		public var pt2:IntPoint;
	}
}