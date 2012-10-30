package com.logicom.geom 
{
	internal final class TEdge 
	{
		public var xbot:int;
		public var ybot:int;
		public var xcurr:int;
		public var ycurr:int;
		public var xtop:int;
		public var ytop:int;
		public var dx:Number;
		public var tmpX:int;
		public var polyType:int; //PolyType 
		public var side:int; //EdgeSide 
		public var windDelta:int; //1 or -1 depending on winding direction
		public var windCnt:int;
		public var windCnt2:int; //winding count of the opposite polytype
		public var outIdx:int;
		public var next:TEdge;
		public var prev:TEdge;
		public var nextInLML:TEdge;
		public var nextInAEL:TEdge;
		public var prevInAEL:TEdge;
		public var nextInSEL:TEdge;
		public var prevInSEL:TEdge;
	}
}