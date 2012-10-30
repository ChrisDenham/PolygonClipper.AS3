/*******************************************************************************
*                                                                              *
* Author    :  Angus Johnson                                                   *
* Version   :  4.8.8                                                           *
* Date      :  30 August 2012                                                  *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2010-2012                                         *
*                                                                              *
* License:                                                                     *
* Use, modification & distribution is subject to Boost Software License Ver 1. *
* http://www.boost.org/LICENSE_1_0.txt                                         *
*                                                                              *
* Attributions:                                                                *
* The code in this library is an extension of Bala Vatti's clipping algorithm: *
* "A generic solution to polygon clipping"                                     *
* Communications of the ACM, Vol 35, Issue 7 (July 1992) pp 56-63.             *
* http://portal.acm.org/citation.cfm?id=129906                                 *
*                                                                              *
* Computer graphics and geometric modeling: implementation and algorithms      *
* By Max K. Agoston                                                            *
* Springer; 1 edition (January 4, 2005)                                        *
* http://books.google.com/books?q=vatti+clipping+agoston                       *
*                                                                              *
* See also:                                                                    *
* "Polygon Offsetting by Computing Winding Numbers"                            *
* Paper no. DETC2005-85513 pp. 565-575                                         *
* ASME 2005 International Design Engineering Technical Conferences             *
* and Computers and Information in Engineering Conference (IDETC/CIE2005)      *
* September 24–28, 2005 , Long Beach, California, USA                          *
* http://www.me.berkeley.edu/~mcmains/pubs/DAC05OffsetPolygon.pdf              *
*                                                                              *
*******************************************************************************/

/*******************************************************************************
*                                                                              *
* This is a translation of the C# Clipper library to Flash AS3.                *
* Ported by: Chris Denham                                                      *
* Date: 29 October 2012                                                        *
* http://www.virtualworlds.co.uk                                               *
*                                                                              *
*******************************************************************************/

package com.logicom.geom
{
	import flash.geom.Point;
	
	public class Clipper extends ClipperBase
	{
		public static function clipPolygon(subjectPolygonFloat:Array, clipPolygonFloat:Array, clipType:int):Array
		{			
			var subjectPolygon:Polygon = new Polygon();
			var clipPolygon:Polygon = new Polygon();

			// Convert flash.geom.Point arrays into IntPoint vectors
			var point:Point;			
			for each (point in subjectPolygonFloat) 
			{				
				subjectPolygon.addPoint(new IntPoint(Math.round(point.x) as int, Math.round(point.y) as int));			
			}			
			for each (point in clipPolygonFloat) 
			{				
				clipPolygon.addPoint(new IntPoint(Math.round(point.x) as int, Math.round(point.y) as int));			
			}
			
			var clipper:Clipper = new Clipper();
			clipper.addPolygon(subjectPolygon, PolyType.SUBJECT);
			clipper.addPolygon(clipPolygon, PolyType.CLIP);
			
			var solution:Polygons = new Polygons();
			clipper.execute(clipType, solution, PolyFillType.EVEN_ODD, PolyFillType.EVEN_ODD);
			var ret:Array = [];			
			for each (var solutionPoly:Polygon in solution.getPolygons()) 
			{
				var n:int = solutionPoly.getSize();
				var points:Array = new Array(n);				
				for (var i:int = 0; i < n; ++i) 
				{
					var p:IntPoint = solutionPoly.getPoint(i);
					points[i] = new Point(p.X, p.Y);
				}				
				ret.push(points);			
			}			
			return ret;		
	
		}

		private var m_PolyOuts:Vector.<OutRec>;
		private var m_ClipType:int; //ClipType 
		private var m_Scanbeam:Scanbeam;
		private var m_ActiveEdges:TEdge;
		private var m_SortedEdges:TEdge;
		private var m_IntersectNodes:IntersectNode;
		private var m_ExecuteLocked:Boolean;
		private var m_ClipFillType:int; //PolyFillType 
		private var m_SubjFillType:int; //PolyFillType 
		private var m_Joins:Vector.<JoinRec>;
		private var m_HorizJoins:Vector.<HorzJoinRec>;
		private var m_ReverseOutput:Boolean;

		public function Clipper()
		{
			m_Scanbeam = null;
			m_ActiveEdges = null;
			m_SortedEdges = null;
			m_IntersectNodes = null;
			m_ExecuteLocked = false;
			m_PolyOuts = new Vector.<OutRec>();
			m_Joins = new Vector.<JoinRec>();
			m_HorizJoins = new Vector.<HorzJoinRec>();
			m_ReverseOutput = false;
		}
		//------------------------------------------------------------------------------

		override public function clear():void
		{
			if (m_edges.length == 0) return; //avoids problems with ClipperBase destructor
			disposeAllPolyPts();
			super.clear();
		}
		//------------------------------------------------------------------------------

		private function disposeScanbeamList():void
		{
			while ( m_Scanbeam != null ) 
			{
				var sb2:Scanbeam = m_Scanbeam.next;
				m_Scanbeam = null;
				m_Scanbeam = sb2;
			}
		}
		//------------------------------------------------------------------------------

		override protected function reset() : void 
		{
			super.reset();
			m_Scanbeam = null;
			m_ActiveEdges = null;
			m_SortedEdges = null;
			disposeAllPolyPts();
			var lm:LocalMinima = m_MinimaList;
			while (lm != null)
			{
				insertScanbeam(lm.Y);
				insertScanbeam(lm.leftBound.ytop);
				lm = lm.next;
			}
		}
		//------------------------------------------------------------------------------

		public function setReverseSolution(reverse:Boolean):void
		{
			m_ReverseOutput = reverse;
		}
		//------------------------------------------------------------------------------
		
		public function getReverseSolution():Boolean
		{
			return m_ReverseOutput;
		}
		//------------------------------------------------------------------------------        
		
		private function insertScanbeam(Y:int):void
		{
			if (m_Scanbeam == null)
			{
				m_Scanbeam = new Scanbeam();
				m_Scanbeam.next = null;
				m_Scanbeam.Y = Y;
			}
			else if (Y > m_Scanbeam.Y)
			{
				var newSb:Scanbeam = new Scanbeam();
				newSb.Y = Y;
				newSb.next = m_Scanbeam;
				m_Scanbeam = newSb;
			} 
			else
			{
				var sb2:Scanbeam = m_Scanbeam;
				while( sb2.next != null  && ( Y <= sb2.next.Y ) ) sb2 = sb2.next;
				if(  Y == sb2.Y ) return; //ie ignores duplicates
				newSb = new Scanbeam();
				newSb.Y = Y;
				newSb.next = sb2.next;
				sb2.next = newSb;
			}
		}
		//------------------------------------------------------------------------------

		public function execute(
			clipType:int,//ClipType
			solution:Polygons,
			subjFillType:int,//PolyFillType 
			clipFillType:int //PolyFillType 
			):Boolean
		{
			if (m_ExecuteLocked) return false;
			m_ExecuteLocked = true;
			solution.clear();
			m_SubjFillType = subjFillType;
			m_ClipFillType = clipFillType;
			m_ClipType = clipType;
			var succeeded:Boolean = executeInternal(false);
			//build the return polygons ...
			if (succeeded) buildResult(solution);
			m_ExecuteLocked = false;
			return succeeded;
		}
		//------------------------------------------------------------------------------
/*
		public bool Execute(ClipType clipType, ExPolygons solution,
			PolyFillType subjFillType, PolyFillType clipFillType)
		{
			if (m_ExecuteLocked) return false;
			m_ExecuteLocked = true;
			solution.Clear();
			m_SubjFillType = subjFillType;
			m_ClipFillType = clipFillType;
			m_ClipType = clipType;
			bool succeeded = ExecuteInternal(true);
			//build the return polygons ...
			if (succeeded) BuildResultEx(solution);
			m_ExecuteLocked = false;
			return succeeded;
		}
		//------------------------------------------------------------------------------

		public bool Execute(ClipType clipType, Polygons solution)
		{
			return Execute(clipType, solution,
				PolyFillType.pftEvenOdd, PolyFillType.pftEvenOdd);
		}
		//------------------------------------------------------------------------------

		public bool Execute(ClipType clipType, ExPolygons solution)
		{
			return Execute(clipType, solution,
				PolyFillType.pftEvenOdd, PolyFillType.pftEvenOdd);
		}
		//------------------------------------------------------------------------------

		//------------------------------------------------------------------------------
*/
		internal function findAppendLinkEnd(outRec:OutRec):OutRec 
		{
			while (outRec.appendLink != null) outRec = outRec.appendLink;
			return outRec;
		}
		//------------------------------------------------------------------------------

		internal function fixHoleLinkage(outRec:OutRec):void
		{
			var tmp:OutRec;
			if (outRec.bottomPt != null) 
				tmp = m_PolyOuts[outRec.bottomPt.idx].firstLeft; 
			else
				tmp = outRec.firstLeft;
			if (outRec == tmp) throw new ClipperException("HoleLinkage error");

			if (tmp != null) 
			{
				if (tmp.appendLink != null) tmp = findAppendLinkEnd(tmp);

				if (tmp == outRec) tmp = null;
				else if (tmp.isHole)
				{
					fixHoleLinkage(tmp);
					tmp = tmp.firstLeft;
				}
			}
			outRec.firstLeft = tmp;
			if (tmp == null) outRec.isHole = false;
			outRec.appendLink = null;
		}
		//------------------------------------------------------------------------------
		
		private function executeInternal(fixHoleLinkages:Boolean):Boolean
		{
			var succeeded:Boolean;
			try
			{
				reset();
				if (m_CurrentLM == null) return true;
				var botY:int = popScanbeam();
				do
				{
					insertLocalMinimaIntoAEL(botY);
					m_HorizJoins.length = 0; //clear;
					processHorizontals();
					var topY:int = popScanbeam();
					succeeded = processIntersections(botY, topY);
					if (!succeeded) break;
					processEdgesAtTopOfScanbeam(topY);
					botY = topY;
				} while (m_Scanbeam != null);
			}
			catch (e:Error) 
			{ 
				succeeded = false; 
			}

			if (succeeded)
			{ 
				//tidy up output polygons and fix orientations where necessary ...
				for each (var outRec:OutRec in m_PolyOuts)
				{
					if (outRec.pts == null) continue;
					fixupOutPolygon(outRec);
					if (outRec.pts == null) continue;
					if (outRec.isHole && fixHoleLinkages) fixHoleLinkage(outRec);

					if (outRec.bottomPt == outRec.bottomFlag &&
						(orientationOutRec(outRec, m_UseFullRange) != (areaOutRec(outRec, m_UseFullRange) > 0)))
					{
						disposeBottomPt(outRec);
					}

					if (outRec.isHole == xor(m_ReverseOutput, orientationOutRec(outRec, m_UseFullRange)))
					{
						reversePolyPtLinks(outRec.pts);
					}
				}

				joinCommonEdges(fixHoleLinkages);
				if (fixHoleLinkages) m_PolyOuts.sort(polySort);
			}
			m_Joins.length = 0; // clear
			m_HorizJoins.length = 0; // clear
			return succeeded;
		}
		//------------------------------------------------------------------------------

		private static function polySort(or1:OutRec, or2:OutRec):int
		{
			if (or1 == or2)
			{
				return 0;
			}
			else if (or1.pts == null || or2.pts == null)
			{
				if ((or1.pts == null) != (or2.pts == null))
				{
					return or1.pts == null ? 1 : -1;
				}
				else return 0;          
			}
			
			var i1:int, i2:int;
			if (or1.isHole)
				i1 = or1.firstLeft.idx; 
			else
				i1 = or1.idx;
				
			if (or2.isHole)
				i2 = or2.firstLeft.idx; 
			else
				i2 = or2.idx;
				
			var result:int = i1 - i2;
			if (result == 0 && (or1.isHole != or2.isHole))
			{
				return or1.isHole ? 1 : -1;
			}
			return result;
		}
		//------------------------------------------------------------------------------
		
		private function popScanbeam():int
		{
			var Y:int = m_Scanbeam.Y;
			var sb2:Scanbeam = m_Scanbeam;
			m_Scanbeam = m_Scanbeam.next;
			sb2 = null;
			return Y;
		}
		//------------------------------------------------------------------------------
		
		private function disposeAllPolyPts():void
		{
		  for (var i:int = 0; i < m_PolyOuts.length; ++i) disposeOutRec(i);
		  m_PolyOuts.length = 0;
		}
		//------------------------------------------------------------------------------

		private function disposeBottomPt(outRec:OutRec):void
		{
			var next:OutPt = outRec.bottomPt.next;
			var prev:OutPt = outRec.bottomPt.prev;
			if (outRec.pts == outRec.bottomPt) outRec.pts = next;
			outRec.bottomPt = null;
			next.prev = prev;
			prev.next = next;
			outRec.bottomPt = next;
			fixupOutPolygon(outRec);
		}
		//------------------------------------------------------------------------------

		private function disposeOutRec(index:int):void
		{
		  var outRec:OutRec = m_PolyOuts[index];
		  if (outRec.pts != null) disposeOutPts(outRec.pts);
		  outRec = null;
		  m_PolyOuts[index] = null;
		}
		//------------------------------------------------------------------------------

		private function disposeOutPts(pp:OutPt):void
		{
			if (pp == null) return;
			var tmpPp:OutPt = null;
			pp.prev.next = null;
			while (pp != null)
			{
				tmpPp = pp;
				pp = pp.next;
				tmpPp = null;
			}
		}
		//------------------------------------------------------------------------------

		private function addJoin(e1:TEdge, e2:TEdge, e1OutIdx:int, e2OutIdx:int):void
		{
			var jr:JoinRec = new JoinRec();
			if (e1OutIdx >= 0)
				jr.poly1Idx = e1OutIdx; else
			jr.poly1Idx = e1.outIdx;
			jr.pt1a = new IntPoint(e1.xcurr, e1.ycurr);
			jr.pt1b = new IntPoint(e1.xtop, e1.ytop);
			if (e2OutIdx >= 0)
				jr.poly2Idx = e2OutIdx; else
				jr.poly2Idx = e2.outIdx;
			jr.pt2a = new IntPoint(e2.xcurr, e2.ycurr);
			jr.pt2b = new IntPoint(e2.xtop, e2.ytop);
			m_Joins.push(jr);
		}
		//------------------------------------------------------------------------------

		private function addHorzJoin(e:TEdge, idx:int):void
		{
			var hj:HorzJoinRec = new HorzJoinRec();
			hj.edge = e;
			hj.savedIdx = idx;
			m_HorizJoins.push(hj);
		}
		//------------------------------------------------------------------------------

		private function insertLocalMinimaIntoAEL(botY:int):void
		{
			while(  m_CurrentLM != null  && ( m_CurrentLM.Y == botY ) )
			{
				var lb:TEdge = m_CurrentLM.leftBound;
				var rb:TEdge = m_CurrentLM.rightBound;

				insertEdgeIntoAEL( lb );
				insertScanbeam( lb.ytop );
				insertEdgeIntoAEL( rb );

				if (isEvenOddFillType(lb))
				{
					lb.windDelta = 1;
					rb.windDelta = 1;
				}
				else
				{
					rb.windDelta = -lb.windDelta;
				}
				setWindingCount(lb);
				rb.windCnt = lb.windCnt;
				rb.windCnt2 = lb.windCnt2;

				if(  rb.dx == horizontal )
				{
					//nb: only rightbounds can have a horizontal bottom edge
					addEdgeToSEL( rb );
					insertScanbeam( rb.nextInLML.ytop );
				}
				else
					insertScanbeam( rb.ytop );

				if( isContributing(lb) )
					addLocalMinPoly(lb, rb, new IntPoint(lb.xcurr, m_CurrentLM.Y));

				//if any output polygons share an edge, they'll need joining later ...
				if (rb.outIdx >= 0)
				{
					if (rb.dx == horizontal)
					{
						for (var i:int = 0; i < m_HorizJoins.length; i++)
						{
							var hj:HorzJoinRec = m_HorizJoins[i];
							//if horizontals rb and hj.edge overlap, flag for joining later ...
							var pt1a:IntPoint = new IntPoint(hj.edge.xbot, hj.edge.ybot);
							var pt1b:IntPoint = new IntPoint(hj.edge.xtop, hj.edge.ytop);
							var pt2a:IntPoint =	new IntPoint(rb.xbot, rb.ybot);
							var pt2b:IntPoint =	new IntPoint(rb.xtop, rb.ytop); 
							if (getOverlapSegment(new Segment(pt1a, pt1b), new Segment(pt2a, pt2b), new Segment(null, null)))
							{
								addJoin(hj.edge, rb, hj.savedIdx, -1);
							}
						}
					}
				}


				if( lb.nextInAEL != rb )
				{
					if (rb.outIdx >= 0 && rb.prevInAEL.outIdx >= 0 && 
						slopesEqual(rb.prevInAEL, rb, m_UseFullRange))
					{
						addJoin(rb, rb.prevInAEL, -1, -1);
					}
					var e:TEdge = lb.nextInAEL;
					var pt:IntPoint = new IntPoint(lb.xcurr, lb.ycurr);
					while( e != rb )
					{
						if(e == null) 
							throw new ClipperException("InsertLocalMinimaIntoAEL: missing rightbound!");
						//nb: For calculating winding counts etc, IntersectEdges() assumes
						//that param1 will be to the right of param2 ABOVE the intersection ...
						intersectEdges( rb , e , pt , Protects.NONE); //order important here
						e = e.nextInAEL;
					}
				}
				popLocalMinima();
			}
		}
		//------------------------------------------------------------------------------

		private function insertEdgeIntoAEL(edge:TEdge):void
		{
			edge.prevInAEL = null;
			edge.nextInAEL = null;
			if (m_ActiveEdges == null)
			{
				m_ActiveEdges = edge;
			}
			else if( E2InsertsBeforeE1(m_ActiveEdges, edge) )
			{
				edge.nextInAEL = m_ActiveEdges;
				m_ActiveEdges.prevInAEL = edge;
				m_ActiveEdges = edge;
			} 
			else
			{
				var e:TEdge = m_ActiveEdges;
				while (e.nextInAEL != null && !E2InsertsBeforeE1(e.nextInAEL, edge))
				  e = e.nextInAEL;
				edge.nextInAEL = e.nextInAEL;
				if (e.nextInAEL != null) e.nextInAEL.prevInAEL = edge;
				edge.prevInAEL = e;
				e.nextInAEL = edge;
			}
		}
		//----------------------------------------------------------------------

		private function E2InsertsBeforeE1(e1:TEdge, e2:TEdge):Boolean
		{
			return e2.xcurr == e1.xcurr? e2.dx > e1.dx : e2.xcurr < e1.xcurr;
		}
		//------------------------------------------------------------------------------

		private function isEvenOddFillType(edge:TEdge):Boolean
		{
		  if (edge.polyType == PolyType.SUBJECT)
			  return m_SubjFillType == PolyFillType.EVEN_ODD; 
		  else
			  return m_ClipFillType == PolyFillType.EVEN_ODD;
		}
		//------------------------------------------------------------------------------

		private function isEvenOddAltFillType(edge:TEdge):Boolean 
		{
		  if (edge.polyType == PolyType.SUBJECT)
			  return m_ClipFillType == PolyFillType.EVEN_ODD; 
		  else
			  return m_SubjFillType == PolyFillType.EVEN_ODD;
		}
		//------------------------------------------------------------------------------

		private function isContributing(edge:TEdge):Boolean
		{
			var pft:int, pft2:int; //PolyFillType
			if (edge.polyType == PolyType.SUBJECT)
			{
				pft = m_SubjFillType;
				pft2 = m_ClipFillType;
			}
			else
			{
				pft = m_ClipFillType;
				pft2 = m_SubjFillType;
			}

			switch (pft)
			{
				case PolyFillType.EVEN_ODD:
				case PolyFillType.NON_ZERO:
					if (abs(edge.windCnt) != 1) return false;
					break;
				case PolyFillType.POSITIVE:
					if (edge.windCnt != 1) return false;
					break;
				default: //PolyFillType.NEGATIVE
					if (edge.windCnt != -1) return false; 
					break;
			}

			switch (m_ClipType)
			{
				case ClipType.INTERSECTION:
					switch (pft2)
					{
						case PolyFillType.EVEN_ODD:
						case PolyFillType.NON_ZERO:
							return (edge.windCnt2 != 0);
						case PolyFillType.POSITIVE:
							return (edge.windCnt2 > 0);
						default:
							return (edge.windCnt2 < 0);
					}
				case ClipType.UNION:
					switch (pft2)
					{
						case PolyFillType.EVEN_ODD:
						case PolyFillType.NON_ZERO:
							return (edge.windCnt2 == 0);
						case PolyFillType.POSITIVE:
							return (edge.windCnt2 <= 0);
						default:
							return (edge.windCnt2 >= 0);
					}
				case ClipType.DIFFERENCE:
					if (edge.polyType == PolyType.SUBJECT)
						switch (pft2)
						{
							case PolyFillType.EVEN_ODD:
							case PolyFillType.NON_ZERO:
								return (edge.windCnt2 == 0);
							case PolyFillType.POSITIVE:
								return (edge.windCnt2 <= 0);
							default:
								return (edge.windCnt2 >= 0);
						}
					else
						switch (pft2)
						{
							case PolyFillType.EVEN_ODD:
							case PolyFillType.NON_ZERO:
								return (edge.windCnt2 != 0);
							case PolyFillType.POSITIVE:
								return (edge.windCnt2 > 0);
							default:
								return (edge.windCnt2 < 0);
						}
			}
			return true;
		}
		//------------------------------------------------------------------------------

		private function setWindingCount(edge:TEdge):void
		{
			var e:TEdge = edge.prevInAEL;
			//find the edge of the same polytype that immediately preceeds 'edge' in AEL
			while (e != null && e.polyType != edge.polyType)
				e = e.prevInAEL;
			if (e == null)
			{
				edge.windCnt = edge.windDelta;
				edge.windCnt2 = 0;
				e = m_ActiveEdges; //ie get ready to calc windCnt2
			}
			else if (isEvenOddFillType(edge))
			{
				//even-odd filling ...
				edge.windCnt = 1;
				edge.windCnt2 = e.windCnt2;
				e = e.nextInAEL; //ie get ready to calc windCnt2
			}
			else
			{
				//nonZero filling ...
				if (e.windCnt * e.windDelta < 0)
				{
					if (abs(e.windCnt) > 1)
					{
						if (e.windDelta * edge.windDelta < 0)
							edge.windCnt = e.windCnt;
						else
							edge.windCnt = e.windCnt + edge.windDelta;
					}
					else
						edge.windCnt = e.windCnt + e.windDelta + edge.windDelta;
				}
				else
				{
					if (abs(e.windCnt) > 1 && e.windDelta * edge.windDelta < 0)
						edge.windCnt = e.windCnt;
					else if (e.windCnt + edge.windDelta == 0)
						edge.windCnt = e.windCnt;
					else
						edge.windCnt = e.windCnt + edge.windDelta;
				}
				edge.windCnt2 = e.windCnt2;
				e = e.nextInAEL; //ie get ready to calc windCnt2
			}

			//update windCnt2 ...
			if (isEvenOddAltFillType(edge))
			{
				//even-odd filling ...
				while (e != edge)
				{
					edge.windCnt2 = (edge.windCnt2 == 0) ? 1 : 0;
					e = e.nextInAEL;
				}
			}
			else
			{
				//nonZero filling ...
				while (e != edge)
				{
					edge.windCnt2 += e.windDelta;
					e = e.nextInAEL;
				}
			}
		}
		//------------------------------------------------------------------------------

		private function addEdgeToSEL(edge:TEdge):void
		{
			//SEL pointers in PEdge are reused to build a list of horizontal edges.
			//However, we don't need to worry about order with horizontal edge processing.
			if (m_SortedEdges == null)
			{
				m_SortedEdges = edge;
				edge.prevInSEL = null;
				edge.nextInSEL = null;
			}
			else
			{
				edge.nextInSEL = m_SortedEdges;
				edge.prevInSEL = null;
				m_SortedEdges.prevInSEL = edge;
				m_SortedEdges = edge;
			}
		}
		//------------------------------------------------------------------------------

		private function copyAELToSEL():void
		{
			var e:TEdge = m_ActiveEdges;
			m_SortedEdges = e;
			if (m_ActiveEdges == null)
				return;
			m_SortedEdges.prevInSEL = null;
			e = e.nextInAEL;
			while (e != null)
			{
				e.prevInSEL = e.prevInAEL;
				e.prevInSEL.nextInSEL = e;
				e.nextInSEL = null;
				e = e.nextInAEL;
			}
		}
		//------------------------------------------------------------------------------

		private function swapPositionsInAEL(edge1:TEdge, edge2:TEdge):void
		{
			if (edge1.nextInAEL == null && edge1.prevInAEL == null)
				return;
			if (edge2.nextInAEL == null && edge2.prevInAEL == null)
				return;

			if (edge1.nextInAEL == edge2)
			{
				var next:TEdge = edge2.nextInAEL;
				if (next != null)
					next.prevInAEL = edge1;
				var prev:TEdge = edge1.prevInAEL;
				if (prev != null)
					prev.nextInAEL = edge2;
				edge2.prevInAEL = prev;
				edge2.nextInAEL = edge1;
				edge1.prevInAEL = edge2;
				edge1.nextInAEL = next;
			}
			else if (edge2.nextInAEL == edge1)
			{
				next = edge1.nextInAEL;
				if (next != null)
					next.prevInAEL = edge2;
				prev = edge2.prevInAEL;
				if (prev != null)
					prev.nextInAEL = edge1;
				edge1.prevInAEL = prev;
				edge1.nextInAEL = edge2;
				edge2.prevInAEL = edge1;
				edge2.nextInAEL = next;
			}
			else
			{
				next = edge1.nextInAEL;
				prev = edge1.prevInAEL;
				edge1.nextInAEL = edge2.nextInAEL;
				if (edge1.nextInAEL != null)
					edge1.nextInAEL.prevInAEL = edge1;
				edge1.prevInAEL = edge2.prevInAEL;
				if (edge1.prevInAEL != null)
					edge1.prevInAEL.nextInAEL = edge1;
				edge2.nextInAEL = next;
				if (edge2.nextInAEL != null)
					edge2.nextInAEL.prevInAEL = edge2;
				edge2.prevInAEL = prev;
				if (edge2.prevInAEL != null)
					edge2.prevInAEL.nextInAEL = edge2;
			}

			if (edge1.prevInAEL == null)
				m_ActiveEdges = edge1;
			else if (edge2.prevInAEL == null)
				m_ActiveEdges = edge2;
		}
		//------------------------------------------------------------------------------

		private function swapPositionsInSEL(edge1:TEdge, edge2:TEdge):void
		{
			if (edge1.nextInSEL == null && edge1.prevInSEL == null)
				return;
			if (edge2.nextInSEL == null && edge2.prevInSEL == null)
				return;

			if (edge1.nextInSEL == edge2)
			{
				var next:TEdge = edge2.nextInSEL;
				if (next != null)
					next.prevInSEL = edge1;
				var prev:TEdge = edge1.prevInSEL;
				if (prev != null)
					prev.nextInSEL = edge2;
				edge2.prevInSEL = prev;
				edge2.nextInSEL = edge1;
				edge1.prevInSEL = edge2;
				edge1.nextInSEL = next;
			}
			else if (edge2.nextInSEL == edge1)
			{
				next = edge1.nextInSEL;
				if (next != null)
					next.prevInSEL = edge2;
				prev = edge2.prevInSEL;
				if (prev != null)
					prev.nextInSEL = edge1;
				edge1.prevInSEL = prev;
				edge1.nextInSEL = edge2;
				edge2.prevInSEL = edge1;
				edge2.nextInSEL = next;
			}
			else
			{
				next = edge1.nextInSEL;
				prev = edge1.prevInSEL;
				edge1.nextInSEL = edge2.nextInSEL;
				if (edge1.nextInSEL != null)
					edge1.nextInSEL.prevInSEL = edge1;
				edge1.prevInSEL = edge2.prevInSEL;
				if (edge1.prevInSEL != null)
					edge1.prevInSEL.nextInSEL = edge1;
				edge2.nextInSEL = next;
				if (edge2.nextInSEL != null)
					edge2.nextInSEL.prevInSEL = edge2;
				edge2.prevInSEL = prev;
				if (edge2.prevInSEL != null)
					edge2.prevInSEL.nextInSEL = edge2;
			}

			if (edge1.prevInSEL == null)
				m_SortedEdges = edge1;
			else if (edge2.prevInSEL == null)
				m_SortedEdges = edge2;
		}
		//------------------------------------------------------------------------------

		private function addLocalMaxPoly(e1:TEdge, e2:TEdge, pt:IntPoint):void
		{
			addOutPt(e1, pt);
			if (e1.outIdx == e2.outIdx)
			{
				e1.outIdx = -1;
				e2.outIdx = -1;
			}
			else if (e1.outIdx < e2.outIdx) 
				appendPolygon(e1, e2);
			else 
				appendPolygon(e2, e1);
		}
		//------------------------------------------------------------------------------

		private function addLocalMinPoly(e1:TEdge, e2:TEdge, pt:IntPoint):void
		{
			var e:TEdge, prevE:TEdge;
			if (e2.dx == horizontal || (e1.dx > e2.dx))
			{
				addOutPt(e1, pt);
				e2.outIdx = e1.outIdx;
				e1.side = EdgeSide.LEFT;
				e2.side = EdgeSide.RIGHT;
				e = e1;
				if (e.prevInAEL == e2)
				  prevE = e2.prevInAEL; 
				else
				  prevE = e.prevInAEL;
			}
			else
			{
				addOutPt(e2, pt);
				e1.outIdx = e2.outIdx;
				e1.side = EdgeSide.RIGHT;
				e2.side = EdgeSide.LEFT;
				e = e2;
				if (e.prevInAEL == e1)
					prevE = e1.prevInAEL;
				else
					prevE = e.prevInAEL;
			}

			if (prevE != null && prevE.outIdx >= 0 &&
				(topX(prevE, pt.Y) == topX(e, pt.Y)) &&
				 slopesEqual(e, prevE, m_UseFullRange))
				   addJoin(e, prevE, -1, -1);

		}
		//------------------------------------------------------------------------------

		private function createOutRec():OutRec
		{
			var result:OutRec = new OutRec();
			result.idx = -1;
			result.isHole = false;
			result.firstLeft = null;
			result.appendLink = null;
			result.pts = null;
			result.bottomPt = null;
			result.bottomFlag = null;
			result.sides = EdgeSide.NEITHER;
			return result;
		}
		//------------------------------------------------------------------------------

		private function addOutPt(e:TEdge, pt:IntPoint):void
		{
			var toFront:Boolean = (e.side == EdgeSide.LEFT);
			if (e.outIdx < 0)
			{
				var outRec:OutRec = createOutRec();
				m_PolyOuts.push(outRec);
				outRec.idx = m_PolyOuts.length -1;
				e.outIdx = outRec.idx;
				var op:OutPt = new OutPt();
				outRec.pts = op;
				outRec.bottomPt = op;
				op.pt = pt;
				op.idx = outRec.idx;
				op.next = op;
				op.prev = op;
				setHoleState(e, outRec);
			} 
			else
			{
				outRec = m_PolyOuts[e.outIdx];
				op = outRec.pts;
				var op2:OutPt, opBot:OutPt;
				if (toFront && pointsEqual(pt, op.pt) || 
				  (!toFront && pointsEqual(pt, op.prev.pt)))
				{
					return;
				}

				if ((e.side | outRec.sides) != outRec.sides)
				{
					//check for 'rounding' artefacts ...
					if (outRec.sides == EdgeSide.NEITHER && pt.Y == op.pt.Y)
					if (toFront)
					{
						if (pt.X == op.pt.X + 1) return;    //ie wrong side of bottomPt
					}
					else if (pt.X == op.pt.X - 1) return; //ie wrong side of bottomPt

					outRec.sides = outRec.sides | e.side;
					if (outRec.sides == EdgeSide.BOTH)
					{
						//A vertex from each side has now been added.
						//Vertices of one side of an output polygon are quite commonly close to
						//or even 'touching' edges of the other side of the output polygon.
						//Very occasionally vertices from one side can 'cross' an edge on the
						//the other side. The distance 'crossed' is always less that a unit
						//and is purely an artefact of coordinate rounding. Nevertheless, this
						//results in very tiny self-intersections. Because of the way
						//orientation is calculated, even tiny self-intersections can cause
						//the Orientation function to return the wrong result. Therefore, it's
						//important to ensure that any self-intersections close to BottomPt are
						//detected and removed before orientation is assigned.

						if (toFront)
						{
							opBot = outRec.pts;
							op2 = opBot.next; //op2 == right side
							if (opBot.pt.Y != op2.pt.Y && opBot.pt.Y != pt.Y &&
								((opBot.pt.X - pt.X) / (opBot.pt.Y - pt.Y) <
								(opBot.pt.X - op2.pt.X) / (opBot.pt.Y - op2.pt.Y)))
							{
								outRec.bottomFlag = opBot;
							}
						}
						else
						{
							opBot = outRec.pts.prev;
							op2 = opBot.next; //op2 == left side
							if (opBot.pt.Y != op2.pt.Y && opBot.pt.Y != pt.Y &&
							  ((opBot.pt.X - pt.X) / (opBot.pt.Y - pt.Y) >
							   (opBot.pt.X - op2.pt.X) / (opBot.pt.Y - op2.pt.Y)))
							{
								outRec.bottomFlag = opBot;
							}
						}
					}
				}

				op2 = new OutPt();
				op2.pt = pt;
				op2.idx = outRec.idx;
				if (op2.pt.Y == outRec.bottomPt.pt.Y &&
					op2.pt.X < outRec.bottomPt.pt.X)
				{
					outRec.bottomPt = op2;
				}
				op2.next = op;
				op2.prev = op.prev;
				op2.prev.next = op2;
				op.prev = op2;
				if (toFront) outRec.pts = op2;
			}
		}
		//------------------------------------------------------------------------------

		private function getOverlapSegment(seg1:Segment, seg2:Segment, seg:Segment):Boolean
		{
			//precondition: segments are colinear.
			if ( seg1.pt1.Y == seg1.pt2.Y || abs((seg1.pt1.X - seg1.pt2.X)/(seg1.pt1.Y - seg1.pt2.Y)) > 1 )
			{
				if (seg1.pt1.X > seg1.pt2.X) seg1.swapPoints();
				if (seg2.pt1.X > seg2.pt2.X) seg2.swapPoints();
				if (seg1.pt1.X > seg2.pt1.X) seg.pt1 = seg1.pt1; else seg.pt1 = seg2.pt1;
				if (seg1.pt2.X < seg2.pt2.X) seg.pt2 = seg1.pt2; else seg.pt2 = seg2.pt2;
				return seg.pt1.X < seg.pt2.X;
			} 
			else
			{
				if (seg1.pt1.Y < seg1.pt2.Y) seg1.swapPoints();
				if (seg2.pt1.Y < seg2.pt2.Y) seg2.swapPoints();
				if (seg1.pt1.Y < seg2.pt1.Y) seg.pt1 = seg1.pt1; else seg.pt1 = seg2.pt1;
				if (seg1.pt2.Y > seg2.pt2.Y) seg.pt2 = seg1.pt2; else seg.pt2 = seg2.pt2;
				return seg.pt1.Y > seg.pt2.Y;
			}
		}
		//------------------------------------------------------------------------------

		private function findSegment(ppRef:OutPtRef, seg:Segment):Boolean
		{
			var pp:OutPt = ppRef.outPt;
			if (pp == null) return false;
			var pp2:OutPt = pp;
			var pt1a:IntPoint = seg.pt1;
			var pt2a:IntPoint = seg.pt2;
			var seg1:Segment = new Segment(pt1a, pt2a);
			do
			{
				var seg2:Segment = new Segment(pp.pt, pp.prev.pt);
				if (slopesEqual4(pt1a, pt2a, pp.pt, pp.prev.pt, true) &&
					slopesEqual3(pt1a, pt2a, pp.pt, true) &&
					getOverlapSegment(seg1, seg2, seg))
				{
					return true;
				}
				pp = pp.next;
				ppRef.outPt = pp; // update the reference for the caller.
			} while (pp != pp2);
			return false;
		}
		//------------------------------------------------------------------------------

		internal function pt3IsBetweenPt1AndPt2(pt1:IntPoint, pt2:IntPoint, pt3:IntPoint):Boolean
		{
			if (pointsEqual(pt1, pt3) || pointsEqual(pt2, pt3)) return true;
			else if (pt1.X != pt2.X) return (pt1.X < pt3.X) == (pt3.X < pt2.X);
			else return (pt1.Y < pt3.Y) == (pt3.Y < pt2.Y);
		}
		//------------------------------------------------------------------------------

		private function insertPolyPtBetween(p1:OutPt, p2:OutPt, pt:IntPoint):OutPt
		{
			var result:OutPt = new OutPt();
			result.pt = pt;
			if (p2 == p1.next)
			{
				p1.next = result;
				p2.prev = result;
				result.next = p2;
				result.prev = p1;
			} else
			{
				p2.next = result;
				p1.prev = result;
				result.next = p1;
				result.prev = p2;
			}
			return result;
		}
		//------------------------------------------------------------------------------

		private function setHoleState(e:TEdge, outRec:OutRec):void
		{
			var isHole:Boolean = false;
			var e2:TEdge = e.prevInAEL;
			while (e2 != null)
			{
				if (e2.outIdx >= 0)
				{
					isHole = !isHole;
					if (outRec.firstLeft == null)
						outRec.firstLeft = m_PolyOuts[e2.outIdx];
				}
				e2 = e2.prevInAEL;
			}
			if (isHole) outRec.isHole = true;
		}
		//------------------------------------------------------------------------------

		private function getDx(pt1:IntPoint, pt2:IntPoint):Number
		{
			if (pt1.Y == pt2.Y) return horizontal;
			else return (Number)(pt2.X - pt1.X) / (Number)(pt2.Y - pt1.Y);
		}
		//---------------------------------------------------------------------------

		private function firstIsBottomPt(btmPt1:OutPt, btmPt2:OutPt):Boolean
		{
			var p:OutPt = btmPt1.prev;
			while (pointsEqual(p.pt, btmPt1.pt) && (p != btmPt1)) p = p.prev;
			var dx1p:Number = Math.abs(getDx(btmPt1.pt, p.pt));
			p = btmPt1.next;
			while (pointsEqual(p.pt, btmPt1.pt) && (p != btmPt1)) p = p.next;
			var dx1n:Number = Math.abs(getDx(btmPt1.pt, p.pt));

			p = btmPt2.prev;
			while (pointsEqual(p.pt, btmPt2.pt) && (p != btmPt2)) p = p.prev;
			var dx2p:Number = Math.abs(getDx(btmPt2.pt, p.pt));
			p = btmPt2.next;
			while (pointsEqual(p.pt, btmPt2.pt) && (p != btmPt2)) p = p.next;
			var dx2n:Number = Math.abs(getDx(btmPt2.pt, p.pt));
			return (dx1p >= dx2p && dx1p >= dx2n) || (dx1n >= dx2p && dx1n >= dx2n);
		}
		//------------------------------------------------------------------------------

		private function getBottomPt(pp:OutPt):OutPt
		{
			var dups:OutPt = null;
			var p:OutPt = pp.next;
			while (p != pp)
			{
				if (p.pt.Y > pp.pt.Y)
				{
					pp = p;
					dups = null;
				}
				else if (p.pt.Y == pp.pt.Y && p.pt.X <= pp.pt.X)
				{
					if (p.pt.X < pp.pt.X)
					{
						dups = null;
						pp = p;
					} 
					else
					{
						if (p.next != pp && p.prev != pp) dups = p;
					}
				}
				p = p.next;
			}
			if (dups != null)
			{
				//there appears to be at least 2 vertices at bottomPt so ...
				while (dups != p)
				{
					if (!firstIsBottomPt(p, dups)) pp = dups;
					dups = dups.next;
					while (!pointsEqual(dups.pt, pp.pt)) dups = dups.next;
				}
			}
			return pp;
		}
		//------------------------------------------------------------------------------

		private function getLowermostRec(outRec1:OutRec, outRec2:OutRec):OutRec
		{
			//work out which polygon fragment has the correct hole state ...
			var bPt1:OutPt = outRec1.bottomPt;
			var bPt2:OutPt = outRec2.bottomPt;
			if (bPt1.pt.Y > bPt2.pt.Y) return outRec1;
			else if (bPt1.pt.Y < bPt2.pt.Y) return outRec2;
			else if (bPt1.pt.X < bPt2.pt.X) return outRec1;
			else if (bPt1.pt.X > bPt2.pt.X) return outRec2;
			else if (bPt1.next == bPt1) return outRec2;
			else if (bPt2.next == bPt2) return outRec1;
			else if (firstIsBottomPt(bPt1, bPt2)) return outRec1;
			else return outRec2;
		}
		//------------------------------------------------------------------------------

		private function param1RightOfParam2(outRec1:OutRec, outRec2:OutRec):Boolean
		{
			do
			{
				outRec1 = outRec1.firstLeft;
				if (outRec1 == outRec2) return true;
			} while (outRec1 != null);
			return false;
		}
		//------------------------------------------------------------------------------

		private function appendPolygon(e1:TEdge, e2:TEdge):void
		{
			//get the start and ends of both output polygons ...
			var outRec1:OutRec = m_PolyOuts[e1.outIdx];
			var outRec2:OutRec = m_PolyOuts[e2.outIdx];

			var holeStateRec:OutRec;
			if (param1RightOfParam2(outRec1, outRec2)) holeStateRec = outRec2;
			else if (param1RightOfParam2(outRec2, outRec1)) holeStateRec = outRec1;
			else holeStateRec = getLowermostRec(outRec1, outRec2);

			var p1_lft:OutPt = outRec1.pts;
			var p1_rt:OutPt = p1_lft.prev;
			var p2_lft:OutPt = outRec2.pts;
			var p2_rt:OutPt = p2_lft.prev;

			var side:int; //EdgeSide
			//join e2 poly onto e1 poly and delete pointers to e2 ...
			if(  e1.side == EdgeSide.LEFT )
			{
				if (e2.side == EdgeSide.LEFT)
				{
					//z y x a b c
					reversePolyPtLinks(p2_lft);
					p2_lft.next = p1_lft;
					p1_lft.prev = p2_lft;
					p1_rt.next = p2_rt;
					p2_rt.prev = p1_rt;
					outRec1.pts = p2_rt;
				} 
				else
				{
					//x y z a b c
					p2_rt.next = p1_lft;
					p1_lft.prev = p2_rt;
					p2_lft.prev = p1_rt;
					p1_rt.next = p2_lft;
					outRec1.pts = p2_lft;
				}
				side = EdgeSide.LEFT;
			} 
			else
			{
				if (e2.side == EdgeSide.RIGHT)
				{
					//a b c z y x
					reversePolyPtLinks( p2_lft );
					p1_rt.next = p2_rt;
					p2_rt.prev = p1_rt;
					p2_lft.next = p1_lft;
					p1_lft.prev = p2_lft;
				} 
				else
				{
					//a b c x y z
					p1_rt.next = p2_lft;
					p2_lft.prev = p1_rt;
					p1_lft.prev = p2_rt;
					p2_rt.next = p1_lft;
				}
				side = EdgeSide.RIGHT;
			}

			if (holeStateRec == outRec2)
			{
				outRec1.bottomPt = outRec2.bottomPt;
				outRec1.bottomPt.idx = outRec1.idx;
				if (outRec2.firstLeft != outRec1)
				{
					outRec1.firstLeft = outRec2.firstLeft;
				}
				outRec1.isHole = outRec2.isHole;
			}
			outRec2.pts = null;
			outRec2.bottomPt = null;
			outRec2.appendLink = outRec1;
			var oKIdx:int = e1.outIdx;
			var obsoleteIdx:int = e2.outIdx;

			e1.outIdx = -1; //nb: safe because we only get here via AddLocalMaxPoly
			e2.outIdx = -1;

			var e:TEdge = m_ActiveEdges;
			while( e != null )
			{
				if( e.outIdx == obsoleteIdx )
				{
					e.outIdx = oKIdx;
					e.side = side;
					break;
				}
				e = e.nextInAEL;
			}

			for (var i:int = 0; i < m_Joins.length; ++i)
			{
				if (m_Joins[i].poly1Idx == obsoleteIdx) m_Joins[i].poly1Idx = oKIdx;
				if (m_Joins[i].poly2Idx == obsoleteIdx) m_Joins[i].poly2Idx = oKIdx;
			}

			for (i = 0; i < m_HorizJoins.length; ++i)
			{
				if (m_HorizJoins[i].savedIdx == obsoleteIdx)
				{
					m_HorizJoins[i].savedIdx = oKIdx;
				}
			}
		}
		//------------------------------------------------------------------------------

		private function reversePolyPtLinks(pp:OutPt):void
		{
			var pp1:OutPt;
			var pp2:OutPt;
			pp1 = pp;
			do
			{
				pp2 = pp1.next;
				pp1.next = pp1.prev;
				pp1.prev = pp2;
				pp1 = pp2;
			} while (pp1 != pp);
		}
		//------------------------------------------------------------------------------

		private static function swapSides(edge1:TEdge, edge2:TEdge):void
		{
			var side:int = edge1.side; //EdgeSide
			edge1.side = edge2.side;
			edge2.side = side;
		}
		//------------------------------------------------------------------------------

		private static function swapPolyIndexes(edge1:TEdge, edge2:TEdge):void
		{
			var outIdx:int = edge1.outIdx;
			edge1.outIdx = edge2.outIdx;
			edge2.outIdx = outIdx;
		}
		//------------------------------------------------------------------------------

		private function doEdge1(edge1:TEdge, edge2:TEdge, pt:IntPoint):void
		{
			addOutPt(edge1, pt);
			swapSides(edge1, edge2);
			swapPolyIndexes(edge1, edge2);
		}
		//------------------------------------------------------------------------------

		private function doEdge2(edge1:TEdge, edge2:TEdge, pt:IntPoint):void
		{
			addOutPt(edge2, pt);
			swapSides(edge1, edge2);
			swapPolyIndexes(edge1, edge2);
		}
		//------------------------------------------------------------------------------

		private function doBothEdges(edge1:TEdge, edge2:TEdge, pt:IntPoint):void
		{
			addOutPt(edge1, pt);
			addOutPt(edge2, pt);
			swapSides(edge1, edge2);
			swapPolyIndexes(edge1, edge2);
		}
		//------------------------------------------------------------------------------

		private function intersectEdges(e1:TEdge, e2:TEdge, pt:IntPoint, protects:int):void
		{
			//e1 will be to the left of e2 BELOW the intersection. Therefore e1 is before
			//e2 in AEL except when e1 is being inserted at the intersection point ...

			var e1stops:Boolean = (Protects.LEFT & protects) == 0 && e1.nextInLML == null &&
				e1.xtop == pt.X && e1.ytop == pt.Y;
			var e2stops:Boolean = (Protects.RIGHT & protects) == 0 && e2.nextInLML == null &&
				e2.xtop == pt.X && e2.ytop == pt.Y;
			var e1Contributing:Boolean = (e1.outIdx >= 0);
			var e2contributing:Boolean = (e2.outIdx >= 0);

			//update winding counts...
			//assumes that e1 will be to the right of e2 ABOVE the intersection
			if (e1.polyType == e2.polyType)
			{
				if (isEvenOddFillType(e1))
				{
					var oldE1WindCnt:int = e1.windCnt;
					e1.windCnt = e2.windCnt;
					e2.windCnt = oldE1WindCnt;
				}
				else
				{
					if (e1.windCnt + e2.windDelta == 0) e1.windCnt = -e1.windCnt;
					else e1.windCnt += e2.windDelta;
					if (e2.windCnt - e1.windDelta == 0) e2.windCnt = -e2.windCnt;
					else e2.windCnt -= e1.windDelta;
				}
			}
			else
			{
				if (!isEvenOddFillType(e2)) e1.windCnt2 += e2.windDelta;
				else e1.windCnt2 = (e1.windCnt2 == 0) ? 1 : 0;
				if (!isEvenOddFillType(e1)) e2.windCnt2 -= e1.windDelta;
				else e2.windCnt2 = (e2.windCnt2 == 0) ? 1 : 0;
			}

			var e1FillType:int, e2FillType:int, e1FillType2:int, e2FillType2:int; //PolyFillType 
			if (e1.polyType == PolyType.SUBJECT)
			{
				e1FillType = m_SubjFillType;
				e1FillType2 = m_ClipFillType;
			}
			else
			{
				e1FillType = m_ClipFillType;
				e1FillType2 = m_SubjFillType;
			}
			if (e2.polyType == PolyType.SUBJECT)
			{
				e2FillType = m_SubjFillType;
				e2FillType2 = m_ClipFillType;
			}
			else
			{
				e2FillType = m_ClipFillType;
				e2FillType2 = m_SubjFillType;
			}

			var e1Wc:int, e2Wc:int;
			switch (e1FillType)
			{
				case PolyFillType.POSITIVE: e1Wc = e1.windCnt; break;
				case PolyFillType.NEGATIVE: e1Wc = -e1.windCnt; break;
				default: e1Wc = abs(e1.windCnt); break;
			}
			switch (e2FillType)
			{
				case PolyFillType.POSITIVE: e2Wc = e2.windCnt; break;
				case PolyFillType.NEGATIVE: e2Wc = -e2.windCnt; break;
				default: e2Wc = abs(e2.windCnt); break;
			}


			if (e1Contributing && e2contributing)
			{
				if ( e1stops || e2stops || 
				  (e1Wc != 0 && e1Wc != 1) || (e2Wc != 0 && e2Wc != 1) ||
				  (e1.polyType != e2.polyType && m_ClipType != ClipType.XOR))
					addLocalMaxPoly(e1, e2, pt);
				else
					doBothEdges(e1, e2, pt);
			}
			else if (e1Contributing)
			{
				if ((e2Wc == 0 || e2Wc == 1) && 
				  (m_ClipType != ClipType.INTERSECTION || 
					e2.polyType == PolyType.SUBJECT || (e2.windCnt2 != 0))) 
						doEdge1(e1, e2, pt);
			}
			else if (e2contributing)
			{
				if ((e1Wc == 0 || e1Wc == 1) &&
				  (m_ClipType != ClipType.INTERSECTION ||
								e1.polyType == PolyType.SUBJECT || (e1.windCnt2 != 0))) 
						doEdge2(e1, e2, pt);
			}
			else if ( (e1Wc == 0 || e1Wc == 1) && 
				(e2Wc == 0 || e2Wc == 1) && !e1stops && !e2stops )
			{
				//neither edge is currently contributing ...
				var e1Wc2:int, e2Wc2:int;
				switch (e1FillType2)
				{
					case PolyFillType.POSITIVE: e1Wc2 = e1.windCnt2; break;
					case PolyFillType.NEGATIVE: e1Wc2 = -e1.windCnt2; break;
					default: e1Wc2 = abs(e1.windCnt2); break;
				}
				switch (e2FillType2)
				{
					case PolyFillType.POSITIVE: e2Wc2 = e2.windCnt2; break;
					case PolyFillType.NEGATIVE: e2Wc2 = -e2.windCnt2; break;
					default: e2Wc2 = abs(e2.windCnt2); break;
				}

				if (e1.polyType != e2.polyType)
					addLocalMinPoly(e1, e2, pt);
				else if (e1Wc == 1 && e2Wc == 1)
					switch (m_ClipType)
					{
						case ClipType.INTERSECTION:
							{
								if (e1Wc2 > 0 && e2Wc2 > 0)
									addLocalMinPoly(e1, e2, pt);
								break;
							}
						case ClipType.UNION:
							{
								if (e1Wc2 <= 0 && e2Wc2 <= 0)
									addLocalMinPoly(e1, e2, pt);
								break;
							}
						case ClipType.DIFFERENCE:
							{
								if (((e1.polyType == PolyType.CLIP) && (e1Wc2 > 0) && (e2Wc2 > 0)) ||
								   ((e1.polyType == PolyType.SUBJECT) && (e1Wc2 <= 0) && (e2Wc2 <= 0)))
										addLocalMinPoly(e1, e2, pt);
								break;
							}
						case ClipType.XOR:
							{
								addLocalMinPoly(e1, e2, pt);
								break;
							}
					}
				else 
					swapSides(e1, e2);
			}

			if ((e1stops != e2stops) &&
			  ((e1stops && (e1.outIdx >= 0)) || (e2stops && (e2.outIdx >= 0))))
			{
				swapSides(e1, e2);
				swapPolyIndexes(e1, e2);
			}

			//finally, delete any non-contributing maxima edges  ...
			if (e1stops) deleteFromAEL(e1);
			if (e2stops) deleteFromAEL(e2);
		}
		//------------------------------------------------------------------------------

		private function deleteFromAEL(e:TEdge):void
		{
			var AelPrev:TEdge = e.prevInAEL;
			var AelNext:TEdge = e.nextInAEL;
			if (AelPrev == null && AelNext == null && (e != m_ActiveEdges))
				return; //already deleted
			if (AelPrev != null)
				AelPrev.nextInAEL = AelNext;
			else m_ActiveEdges = AelNext;
			if (AelNext != null)
				AelNext.prevInAEL = AelPrev;
			e.nextInAEL = null;
			e.prevInAEL = null;
		}
		//------------------------------------------------------------------------------

		private function deleteFromSEL(e:TEdge):void
		{
			var SelPrev:TEdge = e.prevInSEL;
			var SelNext:TEdge = e.nextInSEL;
			if (SelPrev == null && SelNext == null && (e != m_SortedEdges))
				return; //already deleted
			if (SelPrev != null)
				SelPrev.nextInSEL = SelNext;
			else m_SortedEdges = SelNext;
			if (SelNext != null)
				SelNext.prevInSEL = SelPrev;
			e.nextInSEL = null;
			e.prevInSEL = null;
		}
		//------------------------------------------------------------------------------

		private function updateEdgeIntoAEL(e:TEdge):TEdge
		{
			if (e.nextInLML == null)
				throw new ClipperException("UpdateEdgeIntoAEL: invalid call");
			var AelPrev:TEdge = e.prevInAEL;
			var AelNext:TEdge  = e.nextInAEL;
			e.nextInLML.outIdx = e.outIdx;
			if (AelPrev != null)
				AelPrev.nextInAEL = e.nextInLML;
			else m_ActiveEdges = e.nextInLML;
			if (AelNext != null)
				AelNext.prevInAEL = e.nextInLML;
			e.nextInLML.side = e.side;
			e.nextInLML.windDelta = e.windDelta;
			e.nextInLML.windCnt = e.windCnt;
			e.nextInLML.windCnt2 = e.windCnt2;
			e = e.nextInLML;
			e.prevInAEL = AelPrev;
			e.nextInAEL = AelNext;
			if (e.dx != horizontal) insertScanbeam(e.ytop);
			return e;
		}
		//------------------------------------------------------------------------------

		private function processHorizontals():void
		{
			var horzEdge:TEdge = m_SortedEdges;
			while (horzEdge != null)
			{
				deleteFromSEL(horzEdge);
				processHorizontal(horzEdge);
				horzEdge = m_SortedEdges;
			}
		}
		//------------------------------------------------------------------------------

		private function processHorizontal(horzEdge:TEdge):void
		{
			var direction:int; // Direction
			var horzLeft:int, horzRight:int;

			if (horzEdge.xcurr < horzEdge.xtop)
			{
				horzLeft = horzEdge.xcurr;
				horzRight = horzEdge.xtop;
				direction = Direction.LEFT_TO_RIGHT;
			}
			else
			{
				horzLeft = horzEdge.xtop;
				horzRight = horzEdge.xcurr;
				direction = Direction.RIGHT_TO_LEFT;
			}

			var eMaxPair:TEdge;
			if (horzEdge.nextInLML != null)
				eMaxPair = null;
			else
				eMaxPair = getMaximaPair(horzEdge);

			var e:TEdge = getNextInAEL(horzEdge, direction);
			while (e != null)
			{
				var eNext:TEdge = getNextInAEL(e, direction);
				if (eMaxPair != null ||
				  ((direction == Direction.LEFT_TO_RIGHT) && (e.xcurr <= horzRight)) ||
				  ((direction == Direction.RIGHT_TO_LEFT) && (e.xcurr >= horzLeft)))
				{
					//ok, so far it looks like we're still in range of the horizontal edge
					if (e.xcurr == horzEdge.xtop && eMaxPair == null)
					{
						if (slopesEqual(e, horzEdge.nextInLML, m_UseFullRange))
						{
							//if output polygons share an edge, they'll need joining later ...
							if (horzEdge.outIdx >= 0 && e.outIdx >= 0)
								addJoin(horzEdge.nextInLML, e, horzEdge.outIdx, -1);
							break; //we've reached the end of the horizontal line
						}
						else if (e.dx < horzEdge.nextInLML.dx)
							//we really have got to the end of the intermediate horz edge so quit.
							//nb: More -ve slopes follow more +ve slopes ABOVE the horizontal.
							break;
					}

					if (e == eMaxPair)
					{
						//horzEdge is evidently a maxima horizontal and we've arrived at its end.
						if (direction == Direction.LEFT_TO_RIGHT)
							intersectEdges(horzEdge, e, new IntPoint(e.xcurr, horzEdge.ycurr), 0);
						else
							intersectEdges(e, horzEdge, new IntPoint(e.xcurr, horzEdge.ycurr), 0);
						if (eMaxPair.outIdx >= 0) throw new ClipperException("ProcessHorizontal error");
						return;
					}
					else if (e.dx == horizontal && !isMinima(e) && !(e.xcurr > e.xtop))
					{
						if (direction == Direction.LEFT_TO_RIGHT)
							intersectEdges(horzEdge, e, new IntPoint(e.xcurr, horzEdge.ycurr),
							  (isTopHorz(horzEdge, e.xcurr)) ? Protects.LEFT : Protects.BOTH);
						else
							intersectEdges(e, horzEdge, new IntPoint(e.xcurr, horzEdge.ycurr),
							  (isTopHorz(horzEdge, e.xcurr)) ? Protects.RIGHT : Protects.BOTH);
					}
					else if (direction == Direction.LEFT_TO_RIGHT)
					{
						intersectEdges(horzEdge, e, new IntPoint(e.xcurr, horzEdge.ycurr),
						  (isTopHorz(horzEdge, e.xcurr)) ? Protects.LEFT : Protects.BOTH);
					}
					else
					{
						intersectEdges(e, horzEdge, new IntPoint(e.xcurr, horzEdge.ycurr),
						  (isTopHorz(horzEdge, e.xcurr)) ? Protects.RIGHT : Protects.BOTH);
					}
					swapPositionsInAEL(horzEdge, e);
				}
				else if ( (direction == Direction.LEFT_TO_RIGHT && 
					e.xcurr > horzRight && horzEdge.nextInSEL == null) || 
					(direction == Direction.RIGHT_TO_LEFT && 
					e.xcurr < horzLeft && horzEdge.nextInSEL == null) )
				{
					break;
				}
				e = eNext;
			} //end while ( e )

			if (horzEdge.nextInLML != null)
			{
				if (horzEdge.outIdx >= 0)
					addOutPt(horzEdge, new IntPoint(horzEdge.xtop, horzEdge.ytop));
				horzEdge = updateEdgeIntoAEL(horzEdge);
			}
			else
			{
				if (horzEdge.outIdx >= 0)
					intersectEdges(horzEdge, eMaxPair, 
						new IntPoint(horzEdge.xtop, horzEdge.ycurr), Protects.BOTH);
				deleteFromAEL(eMaxPair);
				deleteFromAEL(horzEdge);
			}
		}
		//------------------------------------------------------------------------------

		private function isTopHorz(horzEdge:TEdge, XPos:Number):Boolean
		{
			var e:TEdge = m_SortedEdges;
			while (e != null)
			{
				if ((XPos >= Math.min(e.xcurr, e.xtop)) && (XPos <= Math.max(e.xcurr, e.xtop)))
					return false;
				e = e.nextInSEL;
			}
			return true;
		}
		//------------------------------------------------------------------------------

		private static function getNextInAEL(e:TEdge, direction:int):TEdge
		{
			return direction == Direction.LEFT_TO_RIGHT ? e.nextInAEL: e.prevInAEL;
		}
		//------------------------------------------------------------------------------

		private static function isMinima(e:TEdge):Boolean
		{
			return e != null && (e.prev.nextInLML != e) && (e.next.nextInLML != e);
		}
		//------------------------------------------------------------------------------

		private static function isMaxima(e:TEdge, Y:Number):Boolean
		{
			return (e != null && e.ytop == Y && e.nextInLML == null);
		}
		//------------------------------------------------------------------------------

		private static function isIntermediate(e:TEdge, Y:Number):Boolean
		{
			return (e.ytop == Y && e.nextInLML != null);
		}
		//------------------------------------------------------------------------------

		private static function getMaximaPair(e:TEdge):TEdge
		{
			if (!isMaxima(e.next, e.ytop) || (e.next.xtop != e.xtop))
			{
				return e.prev;
			}
			else
			{
				return e.next;
			}
		}
		//------------------------------------------------------------------------------

		private function processIntersections(botY:int, topY:int):Boolean
		{
			if( m_ActiveEdges == null ) return true;
			try {
				buildIntersectList(botY, topY);
				if ( m_IntersectNodes == null) return true;
				if ( fixupIntersections() ) processIntersectList();
				else return false;
			}
			catch (e:Error)
			{
				m_SortedEdges = null;
				disposeIntersectNodes();
				throw new ClipperException("ProcessIntersections error");
			}
			return true;
		}
		//------------------------------------------------------------------------------

		private function buildIntersectList(botY:int, topY:int):void
		{
			if ( m_ActiveEdges == null ) return;

			//prepare for sorting ...
			var e:TEdge = m_ActiveEdges;
			e.tmpX = topX( e, topY );
			m_SortedEdges = e;
			m_SortedEdges.prevInSEL = null;
			e = e.nextInAEL;
			while( e != null )
			{
				e.prevInSEL = e.prevInAEL;
				e.prevInSEL.nextInSEL = e;
				e.nextInSEL = null;
				e.tmpX = topX( e, topY );
				e = e.nextInAEL;
			}

			//bubblesort ...
			var isModified:Boolean = true;
			while( isModified && m_SortedEdges != null )
			{
				isModified = false;
				e = m_SortedEdges;
				while( e.nextInSEL != null )
				{
					var eNext:TEdge = e.nextInSEL;
					var pt:IntPoint = new IntPoint();
					if(e.tmpX > eNext.tmpX && intersectPoint(e, eNext, pt))
					{
						if (pt.Y > botY)
						{
							pt.Y = botY;
							pt.X = topX(e, pt.Y);
						}
						addIntersectNode(e, eNext, pt);
						swapPositionsInSEL(e, eNext);
						isModified = true;
					}
					else
					{
						e = eNext;
					}
				}
				if( e.prevInSEL != null ) e.prevInSEL.nextInSEL = null;
				else break;
			}
			m_SortedEdges = null;
		}
		//------------------------------------------------------------------------------

		private function fixupIntersections():Boolean
		{
			if ( m_IntersectNodes.next == null ) return true;

			copyAELToSEL();
			var int1:IntersectNode = m_IntersectNodes;
			var int2:IntersectNode = m_IntersectNodes.next;
			while (int2 != null)
			{
				var e1:TEdge = int1.edge1;
				var e2:TEdge;
				if (e1.prevInSEL == int1.edge2) e2 = e1.prevInSEL;
				else if (e1.nextInSEL == int1.edge2) e2 = e1.nextInSEL;
				else
				{
					//The current intersection is out of order, so try and swap it with
					//a subsequent intersection ...
					while (int2 != null)
					{
						if (int2.edge1.nextInSEL == int2.edge2 ||
							int2.edge1.prevInSEL == int2.edge2) break;
						else int2 = int2.next;
					}
					if (int2 == null) return false; //oops!!!

					//found an intersect node that can be swapped ...
					swapIntersectNodes(int1, int2);
					e1 = int1.edge1;
					e2 = int1.edge2;
				}
				swapPositionsInSEL(e1, e2);
				int1 = int1.next;
				int2 = int1.next;
			}

			m_SortedEdges = null;

			//finally, check the last intersection too ...
			return (int1.edge1.prevInSEL == int1.edge2 || int1.edge1.nextInSEL == int1.edge2);
		}
		//------------------------------------------------------------------------------

		private function processIntersectList():void
		{
			while( m_IntersectNodes != null )
			{
				var iNode:IntersectNode = m_IntersectNodes.next;
				{
					intersectEdges( m_IntersectNodes.edge1 ,
								m_IntersectNodes.edge2 , m_IntersectNodes.pt, Protects.BOTH );
					swapPositionsInAEL( m_IntersectNodes.edge1 , m_IntersectNodes.edge2 );
				}
				m_IntersectNodes = null;
				m_IntersectNodes = iNode;
			}
		}
		//------------------------------------------------------------------------------

		private static function round(value:Number):int
		{
			return value < 0 ? (int)(value - 0.5) : (int)(value + 0.5);
		}
		//------------------------------------------------------------------------------

		private static function topX(edge:TEdge, currentY:int):int
		{
			if (currentY == edge.ytop)
				return edge.xtop;
			return edge.xbot + round(edge.dx *(currentY - edge.ybot));
		}
		//------------------------------------------------------------------------------
/*
		private Int64 TopX(IntPoint pt1, IntPoint pt2, Int64 currentY)
		{
		  //preconditions: pt1.Y <> pt2.Y and pt1.Y > pt2.Y
		  if (currentY >= pt1.Y) return pt1.X;
		  else if (currentY == pt2.Y) return pt2.X;
		  else if (pt1.X == pt2.X) return pt1.X;
		  else
		  {
			double q = (pt1.X-pt2.X)/(pt1.Y-pt2.Y);
			return (Int64)Round(pt1.X + (currentY - pt1.Y) * q);
		  }
		}
		//------------------------------------------------------------------------------
*/
		private function addIntersectNode(e1:TEdge, e2:TEdge, pt:IntPoint):void
		{
			var newNode:IntersectNode = new IntersectNode();
			newNode.edge1 = e1;
			newNode.edge2 = e2;
			newNode.pt = pt;
			newNode.next = null;
			if (m_IntersectNodes == null) m_IntersectNodes = newNode;
			else if (processParam1BeforeParam2(newNode, m_IntersectNodes))
			{
				newNode.next = m_IntersectNodes;
				m_IntersectNodes = newNode;
			}
			else
			{
				var iNode:IntersectNode = m_IntersectNodes;
				while (iNode.next != null && processParam1BeforeParam2(iNode.next, newNode))
					iNode = iNode.next;
				newNode.next = iNode.next;
				iNode.next = newNode;
			}
		}
		//------------------------------------------------------------------------------

		private function processParam1BeforeParam2(node1:IntersectNode, node2:IntersectNode):Boolean
		{
			var result:Boolean;
			if (node1.pt.Y == node2.pt.Y)
			{
				if (node1.edge1 == node2.edge1 || node1.edge2 == node2.edge1)
				{
					result = node2.pt.X > node1.pt.X;
					return node2.edge1.dx > 0 ? !result : result;
				}
				else if (node1.edge1 == node2.edge2 || node1.edge2 == node2.edge2)
				{
					result = node2.pt.X > node1.pt.X;
					return node2.edge2.dx > 0 ? !result : result;
				}
				else return node2.pt.X > node1.pt.X;
			}
			else return node1.pt.Y > node2.pt.Y;
		}
		//------------------------------------------------------------------------------

		private function swapIntersectNodes(int1:IntersectNode, int2:IntersectNode):void
		{
			var e1:TEdge = int1.edge1;
			var e2:TEdge = int1.edge2;
			var p:IntPoint = int1.pt;
			int1.edge1 = int2.edge1;
			int1.edge2 = int2.edge2;
			int1.pt = int2.pt;
			int2.edge1 = e1;
			int2.edge2 = e2;
			int2.pt = p;
		}
		//------------------------------------------------------------------------------

		private function intersectPoint(edge1:TEdge, edge2:TEdge, ip:IntPoint):Boolean
		{
			var b1:Number, b2:Number;
			if (slopesEqual(edge1, edge2, m_UseFullRange)) return false;
			else if (edge1.dx == 0)
			{
				ip.X = edge1.xbot;
				if (edge2.dx == horizontal)
				{
					ip.Y = edge2.ybot;
				} 
				else
				{
					b2 = edge2.ybot - (edge2.xbot/edge2.dx);
					ip.Y = round(ip.X/edge2.dx + b2);
				}
			}
			else if (edge2.dx == 0)
			{
				ip.X = edge2.xbot;
				if (edge1.dx == horizontal)
				{
					ip.Y = edge1.ybot;
				} 
				else
				{
					b1 = edge1.ybot - (edge1.xbot/edge1.dx);
					ip.Y = round(ip.X/edge1.dx + b1);
				}
			} 
			else
			{
				b1 = edge1.xbot - edge1.ybot * edge1.dx;
				b2 = edge2.xbot - edge2.ybot * edge2.dx;
				b2 = (b2-b1)/(edge1.dx - edge2.dx);
				ip.Y = round(b2);
				ip.X = round(edge1.dx * b2 + b1);
			}

			//can be *so close* to the top of one edge that the rounded Y equals one ytop ...
			return	(ip.Y == edge1.ytop && ip.Y >= edge2.ytop && edge1.tmpX > edge2.tmpX) ||
					(ip.Y == edge2.ytop && ip.Y >= edge1.ytop && edge1.tmpX > edge2.tmpX) ||
					(ip.Y > edge1.ytop && ip.Y > edge2.ytop);
		}
		//------------------------------------------------------------------------------

		private function disposeIntersectNodes():void
		{
			while ( m_IntersectNodes != null )
			{
				var iNode:IntersectNode = m_IntersectNodes.next;
				m_IntersectNodes = null;
				m_IntersectNodes = iNode;
			}
		}
		//------------------------------------------------------------------------------

		private function processEdgesAtTopOfScanbeam(topY:int):void
		{
			var e:TEdge = m_ActiveEdges;
			while( e != null )
			{
				//1. process maxima, treating them as if they're 'bent' horizontal edges,
				//   but exclude maxima with horizontal edges. nb: e can't be a horizontal.
				if( isMaxima(e, topY) && getMaximaPair(e).dx != horizontal )
				{
					//'e' might be removed from AEL, as may any following edges so ...
					var ePrior:TEdge = e.prevInAEL;
					doMaxima(e, topY);
					if( ePrior == null ) e = m_ActiveEdges;
					else e = ePrior.nextInAEL;
				}
				else
				{
					//2. promote horizontal edges, otherwise update xcurr and ycurr ...
					if( isIntermediate(e, topY) && e.nextInLML.dx == horizontal )
					{
						if (e.outIdx >= 0)
						{
							addOutPt(e, new IntPoint(e.xtop, e.ytop));

							for (var i:int = 0; i < m_HorizJoins.length; ++i)
							{
								var hj:HorzJoinRec = m_HorizJoins[i];
								var pt1a:IntPoint = new IntPoint(hj.edge.xbot, hj.edge.ybot);
								var pt1b:IntPoint = new IntPoint(hj.edge.xtop, hj.edge.ytop);
								var pt2a:IntPoint = new IntPoint(e.nextInLML.xbot, e.nextInLML.ybot);
								var pt2b:IntPoint = new IntPoint(e.nextInLML.xtop, e.nextInLML.ytop);
								if (getOverlapSegment(
									new Segment(pt1a, pt1b), 
									new Segment(pt2a, pt2b), 
									new Segment(null, null)))
								{
									addJoin(hj.edge, e.nextInLML, hj.savedIdx, e.outIdx);
								}
							}

							addHorzJoin(e.nextInLML, e.outIdx);
						}
						e = updateEdgeIntoAEL(e);
						addEdgeToSEL(e);
					} 
					else
					{
						//this just simplifies horizontal processing ...
						e.xcurr = topX( e, topY );
						e.ycurr = topY;
					}
					e = e.nextInAEL;
				}
			}

			//3. Process horizontals at the top of the scanbeam ...
			processHorizontals();

			//4. Promote intermediate vertices ...
			e = m_ActiveEdges;
			while( e != null )
			{
				if( isIntermediate( e, topY ) )
				{
					if (e.outIdx >= 0) addOutPt(e, new IntPoint(e.xtop, e.ytop));
					e = updateEdgeIntoAEL(e);

					//if output polygons share an edge, they'll need joining later ...
					if (e.outIdx >= 0 && e.prevInAEL != null && e.prevInAEL.outIdx >= 0 &&
						e.prevInAEL.xcurr == e.xbot && e.prevInAEL.ycurr == e.ybot &&
						slopesEqual4(
							new IntPoint(e.xbot, e.ybot), 
							new IntPoint(e.xtop, e.ytop),
							new IntPoint(e.xbot, e.ybot),
							new IntPoint(e.prevInAEL.xtop, e.prevInAEL.ytop), 
							m_UseFullRange))
					{
						addOutPt(e.prevInAEL, new IntPoint(e.xbot, e.ybot));
						addJoin(e, e.prevInAEL, -1, -1);
					}
					else if (e.outIdx >= 0 && e.nextInAEL != null && e.nextInAEL.outIdx >= 0 &&
						e.nextInAEL.ycurr > e.nextInAEL.ytop &&
						e.nextInAEL.ycurr <= e.nextInAEL.ybot && 
						e.nextInAEL.xcurr == e.xbot && e.nextInAEL.ycurr == e.ybot &&
						slopesEqual4(
							new IntPoint(e.xbot, e.ybot), 
							new IntPoint(e.xtop, e.ytop),
							new IntPoint(e.xbot, e.ybot),
							new IntPoint(e.nextInAEL.xtop, e.nextInAEL.ytop), m_UseFullRange))
					{
						addOutPt(e.nextInAEL, new IntPoint(e.xbot, e.ybot));
						addJoin(e, e.nextInAEL, -1, -1);
					}
				}
				e = e.nextInAEL;
			}
		}
		//------------------------------------------------------------------------------

		private function doMaxima(e:TEdge, topY:int):void
		{
			var eMaxPair:TEdge = getMaximaPair(e);
			var X:int = e.xtop;
			var eNext:TEdge = e.nextInAEL;
			while( eNext != eMaxPair )
			{
				if (eNext == null) throw new ClipperException("DoMaxima error");
				intersectEdges( e, eNext, new IntPoint(X, topY), Protects.BOTH );
				eNext = eNext.nextInAEL;
			}
			if( e.outIdx < 0 && eMaxPair.outIdx < 0 )
			{
				deleteFromAEL( e );
				deleteFromAEL( eMaxPair );
			}
			else if( e.outIdx >= 0 && eMaxPair.outIdx >= 0 )
			{
				intersectEdges(e, eMaxPair, new IntPoint(X, topY), Protects.NONE);
			}
			else throw new ClipperException("DoMaxima error");
		}
		//------------------------------------------------------------------------------

		public static function reversePolygons(polys:Polygons) : void
		{ 
			for each (var poly:Polygon in polys.getPolygons()) poly.reverse();
		}
		//------------------------------------------------------------------------------
		
		public static function orientation(polygon:Polygon):Boolean
		{
			var poly:Vector.<IntPoint> = polygon.getPoints();
			var highI:int = poly.length -1;
			if (highI < 2) return false;
			var j:int = 0, jplus:int, jminus:int;
			for (var i:int = 0; i <= highI; ++i) 
			{
				if (poly[i].Y < poly[j].Y) continue;
				if ((poly[i].Y > poly[j].Y || poly[i].X < poly[j].X)) j = i;
			};
			if (j == highI) jplus = 0;
			else jplus = j +1;
			if (j == 0) jminus = highI;
			else jminus = j -1;

			//get cross product of vectors of the edges adjacent to highest point ...
			var vec1:IntPoint = new IntPoint(poly[j].X - poly[jminus].X, poly[j].Y - poly[jminus].Y);
			var vec2:IntPoint = new IntPoint(poly[jplus].X - poly[j].X, poly[jplus].Y - poly[j].Y);
			if (abs(vec1.X) > loRange || abs(vec1.Y) > loRange ||
				abs(vec2.X) > loRange || abs(vec2.Y) > loRange)
			{
				if (abs(vec1.X) > hiRange || abs(vec1.Y) > hiRange ||
					abs(vec2.X) > hiRange || abs(vec2.Y) > hiRange)
				{
					throw new ClipperException("Coordinate exceeds range bounds.");
				}
				return IntPoint.cross(vec1, vec2) >= 0;
			}
			else
			{
				return IntPoint.cross(vec1, vec2) >=0;
			}
		}
		//------------------------------------------------------------------------------

		private function orientationOutRec(outRec:OutRec, useFull64BitRange:Boolean):Boolean
		{
			//first make sure bottomPt is correctly assigned ...
			var opBottom:OutPt = outRec.pts, op:OutPt = outRec.pts.next;
			while (op != outRec.pts) 
			{
				if (op.pt.Y >= opBottom.pt.Y) 
				{
					if (op.pt.Y > opBottom.pt.Y || op.pt.X < opBottom.pt.X) 
					opBottom = op;
				}
				op = op.next;
			}
			outRec.bottomPt = opBottom;
			opBottom.idx = outRec.idx;
			
			op = opBottom;
			//find vertices either side of bottomPt (skipping duplicate points) ....
			var opPrev:OutPt = op.prev;
			var opNext:OutPt = op.next;
			while (op != opPrev && pointsEqual(op.pt, opPrev.pt)) 
			  opPrev = opPrev.prev;
			while (op != opNext && pointsEqual(op.pt, opNext.pt))
			  opNext = opNext.next;

			var vec1:IntPoint = new IntPoint(op.pt.X - opPrev.pt.X, op.pt.Y - opPrev.pt.Y);
			var vec2:IntPoint = new IntPoint(opNext.pt.X - op.pt.X, opNext.pt.Y - op.pt.Y);

			if (useFull64BitRange)
			{
				//Int128 cross = Int128.Int128Mul(vec1.X, vec2.Y) - Int128.Int128Mul(vec2.X, vec1.Y);
				//return !cross.IsNegative();
				return IntPoint.cross(vec1, vec2) >= 0;
			}
			else
			{
				return IntPoint.cross(vec1, vec2) >= 0;
			}

		}
		//------------------------------------------------------------------------------

		private function pointCount(pts:OutPt):int
		{
			if (pts == null) return 0;
			var result:int = 0;
			var p:OutPt = pts;
			do
			{
				result++;
				p = p.next;
			}
			while (p != pts);
			return result;
		}
		//------------------------------------------------------------------------------

		private function buildResult(polyg:Polygons):void
		{
			polyg.clear();
			for each (var outRec:OutRec in m_PolyOuts)
			{
				if (outRec.pts == null) continue;
				var p:OutPt = outRec.pts;
				var cnt:int = pointCount(p);
				if (cnt < 3) continue;
				var pg:Polygon = new Polygon();
				for (var j:int = 0; j < cnt; j++)
				{
					pg.addPoint(p.pt);
					p = p.next;
				}
				polyg.addPolygon(pg);
			}
		}
		//------------------------------------------------------------------------------
/*
		private void BuildResultEx(ExPolygons polyg)
		{         
			polyg.Clear();
			polyg.Capacity = m_PolyOuts.Count;
			int i = 0;
			while (i < m_PolyOuts.Count)
			{
				OutRec outRec = m_PolyOuts[i++];
				if (outRec.pts == null) break; //nb: already sorted here
				OutPt p = outRec.pts;
				int cnt = PointCount(p);
				if (cnt < 3) continue;
				ExPolygon epg = new ExPolygon();
				epg.outer = new Polygon(cnt);
				epg.holes = new Polygons();
				for (int j = 0; j < cnt; j++)
				{
					epg.outer.Add(p.pt);
					p = p.next;
				}
				while (i < m_PolyOuts.Count)
				{
					outRec = m_PolyOuts[i];
					if (outRec.pts == null || !outRec.isHole) break;
					Polygon pg = new Polygon();
					p = outRec.pts;
					do
					{
						pg.Add(p.pt);
						p = p.next;
					} while (p != outRec.pts);
					epg.holes.Add(pg);
					i++;
				}
				polyg.Add(epg);
			}
		}
		//------------------------------------------------------------------------------
*/
		private function fixupOutPolygon(outRec:OutRec):void
		{
			//FixupOutPolygon() - removes duplicate points and simplifies consecutive
			//parallel edges by removing the middle vertex.
			var lastOK:OutPt  = null;
			outRec.pts = outRec.bottomPt;
			var pp:OutPt = outRec.bottomPt;
			for (;;)
			{
				if (pp.prev == pp || pp.prev == pp.next)
				{
					disposeOutPts(pp);
					outRec.pts = null;
					outRec.bottomPt = null;
					return;
				}
				//test for duplicate points and for same slope (cross-product) ...
				if (pointsEqual(pp.pt, pp.next.pt) ||
				  slopesEqual3(pp.prev.pt, pp.pt, pp.next.pt, m_UseFullRange))
				{
					lastOK = null;
					var tmp:OutPt = pp;
					if (pp == outRec.bottomPt)
						 outRec.bottomPt = null; //flags need for updating
					pp.prev.next = pp.next;
					pp.next.prev = pp.prev;
					pp = pp.prev;
					tmp = null;
				}
				else if (pp == lastOK)
				{
					break;
				}
				else
				{
					if (lastOK == null) lastOK = pp;
					pp = pp.next;
				}
			}
			if (outRec.bottomPt == null) 
			{
				outRec.bottomPt = getBottomPt(pp);
				outRec.bottomPt.idx = outRec.idx;
				outRec.pts = outRec.bottomPt;
			}
		}
		//------------------------------------------------------------------------------

		private function checkHoleLinkages1(outRec1:OutRec, outRec2:OutRec):void
		{
		  //when a polygon is split into 2 polygons, make sure any holes the original
		  //polygon contained link to the correct polygon ...
		  for (var i:int = 0; i < m_PolyOuts.length; ++i)
		  {
			if (m_PolyOuts[i].isHole && m_PolyOuts[i].bottomPt != null &&
				m_PolyOuts[i].firstLeft == outRec1 &&
				!pointInPolygon(m_PolyOuts[i].bottomPt.pt, 
				outRec1.pts, m_UseFullRange))
					m_PolyOuts[i].firstLeft = outRec2;
		  }
		}
		//----------------------------------------------------------------------

		private function checkHoleLinkages2(outRec1:OutRec, outRec2:OutRec):void
		{
		  //if a hole is owned by outRec2 then make it owned by outRec1 ...
		  for (var i:int = 0; i < m_PolyOuts.length; ++i)
			if (m_PolyOuts[i].isHole && m_PolyOuts[i].bottomPt != null &&
			  m_PolyOuts[i].firstLeft == outRec2)
				m_PolyOuts[i].firstLeft = outRec1;
		}
		//----------------------------------------------------------------------

		private function joinCommonEdges(fixHoleLinkages:Boolean):void
		{
			for (var i:int = 0; i < m_Joins.length; i++)
			{
				var j:JoinRec = m_Joins[i];
				var outRec1:OutRec = m_PolyOuts[j.poly1Idx];
				var pp1aRef:OutPtRef = new OutPtRef(outRec1.pts);
				var outRec2:OutRec = m_PolyOuts[j.poly2Idx];
				var pp2aRef:OutPtRef = new OutPtRef(outRec2.pts);
				var seg1:Segment = new Segment(j.pt2a, j.pt2b);
				var seg2:Segment = new Segment(j.pt1a, j.pt1b);
				if (!findSegment(pp1aRef, seg1)) continue;
				if (j.poly1Idx == j.poly2Idx)
				{
					//we're searching the same polygon for overlapping segments so
					//segment 2 mustn't be the same as segment 1 ...
					pp2aRef.outPt = pp1aRef.outPt.next;
					if (!findSegment(pp2aRef, seg2) || (pp2aRef.outPt == pp1aRef.outPt)) continue;
				}
				else if (!findSegment(pp2aRef, seg2)) continue;

				var seg:Segment = new Segment(null, null);
				if (!getOverlapSegment(seg1, seg2, seg)) continue;
				
				var pt1:IntPoint = seg.pt1;
				var pt2:IntPoint = seg.pt2;
				var pt3:IntPoint = seg2.pt1;
				var pt4:IntPoint = seg2.pt2;

				var pp1a:OutPt = pp1aRef.outPt;
				var pp2a:OutPt = pp2aRef.outPt;
				
				var p1:OutPt, p2:OutPt, p3:OutPt, p4:OutPt;
				var prev:OutPt = pp1a.prev;
				//get p1 & p2 polypts - the overlap start & endpoints on poly1

				if (pointsEqual(pp1a.pt, pt1)) p1 = pp1a;
				else if (pointsEqual(prev.pt, pt1)) p1 = prev;
				else p1 = insertPolyPtBetween(pp1a, prev, pt1);

				if (pointsEqual(pp1a.pt, pt2)) p2 = pp1a;
				else if (pointsEqual(prev.pt, pt2)) p2 = prev;
				else if ((p1 == pp1a) || (p1 == prev))
					p2 = insertPolyPtBetween(pp1a, prev, pt2);
				else if (pt3IsBetweenPt1AndPt2(pp1a.pt, p1.pt, pt2))
					p2 = insertPolyPtBetween(pp1a, p1, pt2); 
				else
					p2 = insertPolyPtBetween(p1, prev, pt2);

				//get p3 & p4 polypts - the overlap start & endpoints on poly2
				prev = pp2a.prev;
				if (pointsEqual(pp2a.pt, pt1)) p3 = pp2a;
				else if (pointsEqual(prev.pt, pt1)) p3 = prev;
				else p3 = insertPolyPtBetween(pp2a, prev, pt1);

				if (pointsEqual(pp2a.pt, pt2)) p4 = pp2a;
				else if (pointsEqual(prev.pt, pt2)) p4 = prev;
				else if ((p3 == pp2a) || (p3 == prev))
					p4 = insertPolyPtBetween(pp2a, prev, pt2);
				else if (pt3IsBetweenPt1AndPt2(pp2a.pt, p3.pt, pt2))
					p4 = insertPolyPtBetween(pp2a, p3, pt2);
				else
					p4 = insertPolyPtBetween(p3, prev, pt2);

				//p1.pt should equal p3.pt and p2.pt should equal p4.pt here, so ...
				//join p1 to p3 and p2 to p4 ...
				if (p1.next == p2 && p3.prev == p4)
				{
					p1.next = p3;
					p3.prev = p1;
					p2.prev = p4;
					p4.next = p2;
				}
				else if (p1.prev == p2 && p3.next == p4)
				{
					p1.prev = p3;
					p3.next = p1;
					p2.next = p4;
					p4.prev = p2;
				}
				else
					continue; //an orientation is probably wrong

				if (j.poly2Idx == j.poly1Idx)
				{
					//instead of joining two polygons, we've just created a new one by
					//splitting one polygon into two.
					outRec1.pts = getBottomPt(p1);
					outRec1.bottomPt = outRec1.pts;
					outRec1.bottomPt.idx = outRec1.idx;
					outRec2 = createOutRec();
					m_PolyOuts.push(outRec2);
					outRec2.idx = m_PolyOuts.length - 1;
					j.poly2Idx = outRec2.idx;
					outRec2.pts = getBottomPt(p2);
					outRec2.bottomPt = outRec2.pts;
					outRec2.bottomPt.idx = outRec2.idx;

					if (pointInPolygon(outRec2.pts.pt, outRec1.pts, m_UseFullRange))
					{
						//outRec1 is contained by outRec2 ...
						outRec2.isHole = !outRec1.isHole;
						outRec2.firstLeft = outRec1;
						if (outRec2.isHole == xor(m_ReverseOutput, orientationOutRec(outRec2, m_UseFullRange)))
							reversePolyPtLinks(outRec2.pts);
					}
					else if (pointInPolygon(outRec1.pts.pt, outRec2.pts, m_UseFullRange))
					{
						//outRec2 is contained by outRec1 ...
						outRec2.isHole = outRec1.isHole;
						outRec1.isHole = !outRec2.isHole;
						outRec2.firstLeft = outRec1.firstLeft;
						outRec1.firstLeft = outRec2;
						if (outRec1.isHole == xor(m_ReverseOutput, orientationOutRec(outRec1, m_UseFullRange)))
							reversePolyPtLinks(outRec1.pts);
						//make sure any contained holes now link to the correct polygon ...
						if (fixHoleLinkages) checkHoleLinkages1(outRec1, outRec2);
					}
					else
					{
						outRec2.isHole = outRec1.isHole;
						outRec2.firstLeft = outRec1.firstLeft;
						//make sure any contained holes now link to the correct polygon ...
						if (fixHoleLinkages) checkHoleLinkages1(outRec1, outRec2);
					}

					//now fixup any subsequent m_Joins that match this polygon
					for (var k:int = i + 1; k < m_Joins.length; k++)
					{
						var j2:JoinRec = m_Joins[k];
						if (j2.poly1Idx == j.poly1Idx && pointIsVertex(j2.pt1a, p2))
							j2.poly1Idx = j.poly2Idx;
						if (j2.poly2Idx == j.poly1Idx && pointIsVertex(j2.pt2a, p2))
							j2.poly2Idx = j.poly2Idx;
					}
					
					//now cleanup redundant edges too ...
					fixupOutPolygon(outRec1);
					fixupOutPolygon(outRec2);
					if (orientationOutRec(outRec1, m_UseFullRange) != (areaOutRec(outRec1, m_UseFullRange) > 0))
						disposeBottomPt(outRec1);
					if (orientationOutRec(outRec2, m_UseFullRange) != (areaOutRec(outRec2, m_UseFullRange) > 0)) 
						disposeBottomPt(outRec2);
				}
				else
				{
					//joined 2 polygons together ...

					//make sure any holes contained by outRec2 now link to outRec1 ...
					if (fixHoleLinkages) checkHoleLinkages2(outRec1, outRec2);

					//now cleanup redundant edges too ...
					fixupOutPolygon(outRec1);

					if (outRec1.pts != null)
					{
						outRec1.isHole = !orientationOutRec(outRec1, m_UseFullRange);
						if (outRec1.isHole &&  outRec1.firstLeft == null) 
						  outRec1.firstLeft = outRec2.firstLeft;
					}

					//delete the obsolete pointer ...
					var OKIdx:int = outRec1.idx;
					var ObsoleteIdx:int = outRec2.idx;
					outRec2.pts = null;
					outRec2.bottomPt = null;
					outRec2.appendLink = outRec1;

					//now fixup any subsequent joins that match this polygon
					for (k = i + 1; k < m_Joins.length; k++)
					{
						j2 = m_Joins[k];
						if (j2.poly1Idx == ObsoleteIdx) j2.poly1Idx = OKIdx;
						if (j2.poly2Idx == ObsoleteIdx) j2.poly2Idx = OKIdx;
					}
				}
			}
		}
		//------------------------------------------------------------------------------
/*
		private static bool FullRangeNeeded(Polygon pts)
		{
			bool result = false;
			for (int i = 0; i < pts.Count; i++)
			{
				if (Math.Abs(pts[i].X) > hiRange || Math.Abs(pts[i].Y) > hiRange)
					throw new ClipperException("Coordinate exceeds range bounds.");
				else if (Math.Abs(pts[i].X) > loRange || Math.Abs(pts[i].Y) > loRange)
					result = true;
			}
			return result;
		}
		//------------------------------------------------------------------------------

		public static double Area(Polygon poly)
		{
			int highI = poly.Count - 1;
			if (highI < 2) return 0;
			if (FullRangeNeeded(poly))
			{
				Int128 a = new Int128();
				a = Int128.Int128Mul(poly[highI].X, poly[0].Y) -
					Int128.Int128Mul(poly[0].X, poly[highI].Y);
				for (int i = 0; i < highI; ++i)
					a += Int128.Int128Mul(poly[i].X, poly[i + 1].Y) -
					Int128.Int128Mul(poly[i + 1].X, poly[i].Y);
				return a.ToDouble() / 2;
			}
			else
			{
				double area = (double)poly[highI].X * (double)poly[0].Y -
					(double)poly[0].X * (double)poly[highI].Y;
				for (int i = 0; i < highI; ++i)
					area += (double)poly[i].X * (double)poly[i + 1].Y -
						(double)poly[i + 1].X * (double)poly[i].Y;
				return area / 2;
			}
		}
		//------------------------------------------------------------------------------
*/
		private function areaOutRec(outRec:OutRec, useFull64BitRange:Boolean):Number
		{
			var op:OutPt = outRec.pts;
			/*if (useFull64BitRange) 
			{
				Int128 a = new Int128(0);
				do
				{
					a += Int128.Int128Mul(op.prev.pt.X, op.pt.Y) -
						Int128.Int128Mul(op.pt.X, op.prev.pt.Y);
					op = op.next;
				} while (op != outRec.pts);
				return a.ToDouble() / 2;          
			}
			else */
			{
				var a:Number = 0;
				do {
				  a += (op.prev.pt.X * op.pt.Y) - (op.pt.X * op.prev.pt.Y);
				  op = op.next;
				} while (op != outRec.pts);
				return a/2;
			}
		}
/*
		//------------------------------------------------------------------------------
		// OffsetPolygon functions ...
		//------------------------------------------------------------------------------

		internal static Polygon BuildArc(IntPoint pt, double a1, double a2, double r)
		{
			Int64 steps = Math.Max(6, (int)(Math.Sqrt(Math.Abs(r)) * Math.Abs(a2 - a1)));
			if (steps > 0x100000) steps = 0x100000;
			int n = (int)steps;
			Polygon result = new Polygon(n);
			double da = (a2 - a1) / (n -1);
			double a = a1;
			for (int i = 0; i < n; ++i)
			{
				result.Add(new IntPoint(pt.X + Round(Math.Cos(a) * r), pt.Y + Round(Math.Sin(a) * r)));
				a += da;
			}
			return result;
		}
		//------------------------------------------------------------------------------

		internal static DoublePoint GetUnitNormal(IntPoint pt1, IntPoint pt2)
		{
			double dx = (pt2.X - pt1.X);
			double dy = (pt2.Y - pt1.Y);
			if ((dx == 0) && (dy == 0)) return new DoublePoint();

			double f = 1 * 1.0 / Math.Sqrt(dx * dx + dy * dy);
			dx *= f;
			dy *= f;

			return new DoublePoint(dy, -dx);
		}
		//------------------------------------------------------------------------------

		internal class DoublePoint
		{
			public double X { get; set; }
			public double Y { get; set; }
			public DoublePoint(double x = 0, double y = 0)
			{
				this.X = x; this.Y = y;
			}
		};
		//------------------------------------------------------------------------------

		private class PolyOffsetBuilder
		{
			private Polygons pts; 
			private Polygon currentPoly;
			private List<DoublePoint> normals;
			private double delta, m_R;
			private int m_i, m_j, m_k;
			private const int buffLength = 128;

			public PolyOffsetBuilder(Polygons pts, Polygons solution, double delta, JoinType jointype, double MiterLimit = 2)
			{
				//precondtion: solution != pts

				if (delta == 0)
				{
					solution = pts;
					return;
				}

				this.pts = pts;
				this.delta = delta;
				if (MiterLimit <= 1) MiterLimit = 1;
				double RMin = 2/(MiterLimit*MiterLimit);

				normals = new List<DoublePoint>();

				double deltaSq = delta*delta;
				solution.Clear();
				solution.Capacity = pts.Count;
				for (m_i = 0; m_i < pts.Count; m_i++)
				{
					int len = pts[m_i].Count;
					if (len > 1 && pts[m_i][0].X == pts[m_i][len - 1].X &&
						pts[m_i][0].Y == pts[m_i][len - 1].Y) len--;

					if (len == 0 || (len < 3 && delta <= 0)) 
						continue;
					else if (len == 1)
					{
						Polygon arc;
						arc = BuildArc(pts[m_i][len - 1], 0, 2 * Math.PI, delta);
						solution.Add(arc);
						continue;
					}

					//build normals ...
					normals.Clear();
					normals.Capacity = len;
					for (int j = 0; j < len -1; ++j)
						normals.Add(GetUnitNormal(pts[m_i][j], pts[m_i][j+1]));
					normals.Add(GetUnitNormal(pts[m_i][len - 1], pts[m_i][0]));

					currentPoly = new Polygon();
					m_k = len - 1;
					for (m_j = 0; m_j < len; ++m_j)
					{
						switch (jointype)
						{
							case JoinType.jtMiter:
							{
								m_R = 1 + (normals[m_j].X*normals[m_k].X + 
									normals[m_j].Y*normals[m_k].Y);
								if (m_R >= RMin) DoMiter(); else DoSquare(MiterLimit);
								break;
							}
							case JoinType.jtRound: 
								DoRound();
								break;
							case JoinType.jtSquare:
								DoSquare(1);
								break;
						}
						m_k = m_j;
					}
					solution.Add(currentPoly);
				}

				//finally, clean up untidy corners ...
				Clipper clpr = new Clipper();
				clpr.AddPolygons(solution, PolyType.ptSubject);
				if (delta > 0)
				{
					clpr.Execute(ClipType.ctUnion, solution, PolyFillType.pftPositive, PolyFillType.pftPositive);
				}
				else
				{
					IntRect r = clpr.GetBounds();
					Polygon outer = new Polygon(4);

					outer.Add(new IntPoint(r.left - 10, r.bottom + 10));
					outer.Add(new IntPoint(r.right + 10, r.bottom + 10));
					outer.Add(new IntPoint(r.right + 10, r.top - 10));
					outer.Add(new IntPoint(r.left - 10, r.top - 10));

					clpr.AddPolygon(outer, PolyType.ptSubject);
					clpr.Execute(ClipType.ctUnion, solution, PolyFillType.pftNegative, PolyFillType.pftNegative);
					if (solution.Count > 0)
					{
						solution.RemoveAt(0);
						for (int i = 0; i < solution.Count; i++)
							solution[i].Reverse();
					}
				}
			}
			//------------------------------------------------------------------------------
			
			internal void AddPoint(IntPoint pt)
			{
				int len = currentPoly.Count;
				if (len == currentPoly.Capacity)
					currentPoly.Capacity = len + buffLength;
				currentPoly.Add(pt);
			}
			//------------------------------------------------------------------------------

			internal void DoSquare(double mul)
			{
				IntPoint pt1 = new IntPoint((Int64)Round(pts[m_i][m_j].X + normals[m_k].X * delta),
					(Int64)Round(pts[m_i][m_j].Y + normals[m_k].Y * delta));
				IntPoint pt2 = new IntPoint((Int64)Round(pts[m_i][m_j].X + normals[m_j].X * delta),
					(Int64)Round(pts[m_i][m_j].Y + normals[m_j].Y * delta));
				if ((normals[m_k].X * normals[m_j].Y - normals[m_j].X * normals[m_k].Y) * delta >= 0)
				{
					double a1 = Math.Atan2(normals[m_k].Y, normals[m_k].X);
					double a2 = Math.Atan2(-normals[m_j].Y, -normals[m_j].X);
					a1 = Math.Abs(a2 - a1);
					if (a1 > Math.PI) a1 = Math.PI * 2 - a1;
					double dx = Math.Tan((Math.PI - a1) / 4) * Math.Abs(delta * mul);
					pt1 = new IntPoint((Int64)(pt1.X - normals[m_k].Y * dx),
						(Int64)(pt1.Y + normals[m_k].X * dx));
					AddPoint(pt1);
					pt2 = new IntPoint((Int64)(pt2.X + normals[m_j].Y * dx),
						(Int64)(pt2.Y - normals[m_j].X * dx));
					AddPoint(pt2);
				}
				else
				{
					AddPoint(pt1);
					AddPoint(pts[m_i][m_j]);
					AddPoint(pt2);
				}
			}
			//------------------------------------------------------------------------------

			internal void DoMiter()
			{
				if ((normals[m_k].X * normals[m_j].Y - normals[m_j].X * normals[m_k].Y) * delta >= 0)
				{
					double q = delta / m_R;
					AddPoint(new IntPoint((Int64)Round(pts[m_i][m_j].X + 
						(normals[m_k].X + normals[m_j].X) * q),
						(Int64)Round(pts[m_i][m_j].Y + (normals[m_k].Y + normals[m_j].Y) * q)));
				}
				else
				{
					IntPoint pt1 = new IntPoint((Int64)Round(pts[m_i][m_j].X + normals[m_k].X * delta),
						(Int64)Round(pts[m_i][m_j].Y + normals[m_k].Y * delta));
					IntPoint pt2 = new IntPoint((Int64)Round(pts[m_i][m_j].X + normals[m_j].X * delta),
						(Int64)Round(pts[m_i][m_j].Y + normals[m_j].Y * delta));
					AddPoint(pt1);
					AddPoint(pts[m_i][m_j]);
					AddPoint(pt2);
				}
			}
			//------------------------------------------------------------------------------

			internal void DoRound()
			{
				IntPoint pt1 = new IntPoint(Round(pts[m_i][m_j].X + normals[m_k].X * delta),
					Round(pts[m_i][m_j].Y + normals[m_k].Y * delta));
				IntPoint pt2 = new IntPoint(Round(pts[m_i][m_j].X + normals[m_j].X * delta),
					Round(pts[m_i][m_j].Y + normals[m_j].Y * delta));
				AddPoint(pt1);
				//round off reflex angles (ie > 180 deg) unless almost flat (ie < 10deg).
				//cross product normals < 0 . angle > 180 deg.
				//dot product normals == 1 . no angle
				if ((normals[m_k].X * normals[m_j].Y - normals[m_j].X * normals[m_k].Y) * delta >= 0)
				{
					if ((normals[m_j].X * normals[m_k].X + normals[m_j].Y * normals[m_k].Y) < 0.985)
					{
						double a1 = Math.Atan2(normals[m_k].Y, normals[m_k].X);
						double a2 = Math.Atan2(normals[m_j].Y, normals[m_j].X);
						if (delta > 0 && a2 < a1) a2 += Math.PI * 2;
						else if (delta < 0 && a2 > a1) a2 -= Math.PI * 2;
						Polygon arc = BuildArc(pts[m_i][m_j], a1, a2, delta);
						for (int m = 0; m < arc.Count; m++)
							AddPoint(arc[m]);
					}
				}
				else
					AddPoint(pts[m_i][m_j]);
				AddPoint(pt2);
			}
			//------------------------------------------------------------------------------

		} //end PolyOffsetBuilder
		//------------------------------------------------------------------------------

		public static Polygons OffsetPolygons(Polygons poly, double delta,
			JoinType jointype, double MiterLimit)
		{
			Polygons result = new Polygons(poly.Count);
			new PolyOffsetBuilder(poly, result, delta, jointype, MiterLimit);
			return result;
		}
		//------------------------------------------------------------------------------

		public static Polygons OffsetPolygons(Polygons poly, double delta, JoinType jointype)
		{
			Polygons result = new Polygons(poly.Count);
			new PolyOffsetBuilder(poly, result, delta, jointype, 2.0);
			return result;
		}
		//------------------------------------------------------------------------------

		public static Polygons OffsetPolygons(Polygons poly, double delta)
		{
			Polygons result = new Polygons(poly.Count);
			new PolyOffsetBuilder(poly, result, delta, JoinType.jtSquare, 2.0);
			return result;
		}

		//------------------------------------------------------------------------------
		// SimplifyPolygon functions ...
		// Convert self-intersecting polygons into simple polygons
		//------------------------------------------------------------------------------

		public static Polygons SimplifyPolygon(Polygon poly, 
			  PolyFillType fillType = PolyFillType.pftEvenOdd)
		{
			Polygons result = new Polygons();
			Clipper c = new Clipper();
			c.AddPolygon(poly, PolyType.ptSubject);
			c.Execute(ClipType.ctUnion, result, fillType, fillType);
			return result;
		}
		//------------------------------------------------------------------------------

		public static Polygons SimplifyPolygons(Polygons polys,
			PolyFillType fillType = PolyFillType.pftEvenOdd)
		{
			Polygons result = new Polygons();
			Clipper c = new Clipper();
			c.AddPolygons(polys, PolyType.ptSubject);
			c.Execute(ClipType.ctUnion, result, fillType, fillType);
			return result;
		}
		//------------------------------------------------------------------------------
*/
    }
}

import com.logicom.geom.*;



final class Protects 
{ 
	public static const NONE:int = 0;
	public static const LEFT:int = 1;
	public static const RIGHT:int = 2;
	public static const BOTH:int = 3;
}

final class Direction 
{ 
	public static const RIGHT_TO_LEFT:int = 0;
	public static const LEFT_TO_RIGHT:int = 1;
}

final class Scanbeam
{
	public var Y:int;
	public var next:Scanbeam;
}

final class JoinRec
{
	public var pt1a:IntPoint;
	public var pt1b:IntPoint;
	public var poly1Idx:int;
	public var pt2a:IntPoint;
	public var pt2b:IntPoint;
	public var poly2Idx:int;
}

