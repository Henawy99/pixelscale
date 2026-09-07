// supabase/functions/plan-routes/types.ts
// Shared interfaces for the delivery route planner.

/** A location with lat/lng. */
export interface LatLng {
  lat: number;
  lng: number;
}

/** An order eligible for planning. */
export interface PlannerOrder {
  id: string;
  brandId: string;
  location: LatLng;
  customerName: string | null;
  customerAddress: string | null;
  customerPhone: string | null;
  deliveryNotes: string | null;

  /** When customer expects delivery (the "target" time). */
  targetDeliveryTime: Date;
  /** When kitchen will have it ready (null = ready now). */
  estimatedPickupTime: Date | null;
  /** If set, this is a pre-order with a specific requested time. */
  requestedDeliveryTime: Date | null;
  /** Current delivery status. */
  deliveryStatus: string;
  /** If already assigned to a route. */
  currentRouteId: string | null;
  /** Current driver assignment. */
  currentDriverId: string | null;
  /** Sequence within current route (if any). */
  currentSequence: number | null;

  orderTypeName: string | null; // "Lieferando" | "Foodora" | "Website"
  paymentMethod: string | null;
  totalPrice: number;
  /** Manually pinned driver ID that solver must respect */
  pinnedDriverId?: string | null;
}

/** A driver available for delivery. */
export interface PlannerDriver {
  id: string;
  name: string;
  isOnline: boolean;
  currentLocation: LatLng | null;
  /** ID of current active route (if out on delivery). */
  currentRouteId: string | null;
  /** When the driver is expected back at the restaurant. */
  projectedReturnAt: Date | null;
  /** When driver is available to depart (now or projected return). */
  availableAt?: Date | null;
  /** Scheduled end of driver's shift (null if unlimited/manual). */
  shiftEndAt?: Date | null;
}

/** Tunable planner settings loaded from delivery_settings table. */
export interface PlannerSettings {
  // Cost weights
  lateWeight: number;
  earlyWeight: number;
  driveWeight: number;
  idleWeight: number;
  unassignedWeight: number;

  // Timing (seconds)
  handoverTimeSecs: number;
  earlyGraceSecs: number;
  preorderEarlyGraceSecs: number;
  bundlingWaitSecs: number;
  planningHorizonSecs: number;

  // Shift constraints
  shiftEndGraceMinutes?: number;

  // Fallback
  citySpeedKmh: number;

  // Solver limits
  maxStopsPerRoute: number;
  maxRouteDurationSecs: number;
  solverTimeLimitMs: number;
  exhaustiveThreshold: number;

  // Depot
  storeLocation: LatLng;
}

/** Travel time between two locations. */
export interface TravelTime {
  durationSeconds: number;
  distanceMeters: number;
}

/**
 * Travel time matrix: matrix[fromIdx][toIdx] = TravelTime.
 * Index 0 = restaurant, then orders in the order they appear in the order list.
 */
export type TravelTimeMatrix = TravelTime[][];

/** A stop in a planned route. */
export interface PlannedStop {
  orderId: string | null; // null for depot (store) stops
  type: "store" | "customer_delivery";
  location: LatLng;
  customerName: string | null;
  customerAddress: string | null;
  /** Index into the travel time matrix for this location. */
  matrixIndex: number;
  /** When the planner expects the driver to arrive. */
  plannedArrivalAt: Date;
  /** The order's target delivery time. */
  targetTime: Date | null;
  /** Whether food is ready at planned departure. */
  isReady: boolean;
}

/** A planned route for one driver. */
export interface PlannedRoute {
  driverId: string;
  stops: PlannedStop[]; // First and last are store stops
  totalDrivingSeconds: number;
  totalDistanceMeters: number;
  plannedDepartureAt: Date;
  plannedReturnAt: Date;
}

/** The full output of the planner. */
export interface PlanResult {
  routes: PlannedRoute[];
  unassignedOrderIds: string[];
  costBreakdown: CostBreakdown;
  planVersion: number;
  solverTimeMs: number;
}

/** Detailed cost breakdown for logging. */
export interface CostBreakdown {
  totalCost: number;
  perOrder: OrderCost[];
  totalDrivingMinutes: number;
  totalIdleMinutes: number;
  unassignedCount: number;
}

export interface OrderCost {
  orderId: string;
  latenessMinutes: number;
  earlinessMinutes: number;
  cost: number;
}

// ---- Internal solver types ----

/** Represents a candidate route during solving. */
export interface CandidateRoute {
  driverId: string;
  /** Indices into the matrix for the stops (excluding depot start/end, those are implicit as index 0). */
  stopOrderIndices: number[];
  /** Corresponding order IDs. */
  stopOrderIds: string[];
  /** Whether this driver is currently out (in_progress route). */
  isCurrentlyOut: boolean;
  /** When driver will be available at depot (now if at restaurant, projectedReturn if out). */
  availableAt: Date;
  /** Stops that are already delivered (frozen). */
  frozenStopCount: number;
  /** Driver's scheduled shift end time (null if none). */
  shiftEndAt?: Date | null;
}

/** A full candidate plan (both/all drivers). */
export interface CandidatePlan {
  routes: CandidateRoute[];
}
