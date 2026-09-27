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
  /**
   * When the food is expected to be ready for pickup by a driver.
   * Takes precedence over estimatedPickupTime. null/undefined = use estimatedPickupTime, else "now".
   */
  readyAt?: Date | null;
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
  /**
   * When the driver can leave the restaurant with a new tour.
   * If set, it wins over projectedReturnAt (the planner computes it from the live route).
   */
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
  /** Cost per minute between food ready and handover (freshness). Default 0.5. */
  serviceWeight?: number;
  /** One-off cost for moving an already-assigned order to another driver. Default 30. */
  reassignWeight?: number;

  // Timing (seconds)
  handoverTimeSecs: number;
  earlyGraceSecs: number;
  preorderEarlyGraceSecs: number;
  bundlingWaitSecs: number;
  planningHorizonSecs: number;
  /** Aim to arrive this many seconds before the promised time. Default 120. */
  safetyBufferSecs?: number;

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

/** A planned tour for one driver (restaurant → customers → restaurant). */
export interface PlannedRoute {
  driverId: string;
  stops: PlannedStop[]; // First and last are store stops
  totalDrivingSeconds: number;
  totalDistanceMeters: number;
  plannedDepartureAt: Date;
  plannedReturnAt: Date;
  /** 0 = the driver's next tour, 1 = the one after that, ... */
  tripIndex: number;
}

/** The full output of the planner. */
export interface PlanResult {
  /** Next tour per driver (tripIndex 0). These are committed to the drivers. */
  routes: PlannedRoute[];
  /** Every planned tour, including later ones that are not committed yet. */
  trips: PlannedRoute[];
  unassignedOrderIds: string[];
  costBreakdown: CostBreakdown;
  planVersion: number;
  solverTimeMs: number;
  /** "exact" when the optimum was proven by enumeration, "search" otherwise. */
  method: "exact" | "search" | "empty";
  /** Solver iterations (search) or schedules evaluated (exact). */
  evaluations: number;
}

/** Detailed cost breakdown for logging. */
export interface CostBreakdown {
  totalCost: number;
  perOrder: OrderCost[];
  totalDrivingMinutes: number;
  /** Minutes ready food waited at the restaurant for a driver (summed over orders). */
  totalIdleMinutes: number;
  unassignedCount: number;
}

export interface OrderCost {
  orderId: string;
  latenessMinutes: number;
  earlinessMinutes: number;
  cost: number;
}
