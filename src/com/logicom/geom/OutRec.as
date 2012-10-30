package com.logicom.geom 
{
	internal final class OutRec
	{
		public var idx:int;
		public var isHole:Boolean;
		public var firstLeft:OutRec;
		public var appendLink:OutRec;
		public var pts:OutPt;
		public var bottomPt:OutPt;
		public var bottomFlag:OutPt;
		public var sides:int;//EdgeSide
	}
}