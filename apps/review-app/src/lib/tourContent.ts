/**
 * Product content for the GetYourGuide catalog: descriptions, what's included, prices, start times
 * and the stop-by-stop itinerary. Copied from the Supplier Portal on 2026-09-27 and keyed by the
 * GetYourGuide tour id, so it joins the editable catalog in toursStorage by `gygTourId`.
 * Stop names replace the portal's generic labels ("Traditional village", "View point").
 *
 * When a product changes in the portal, update its entry here to match.
 */

export type TransferMode = 'van' | 'car' | 'cable car';

export type ItineraryStep =
  | { type: 'pickup'; place: string }
  | { type: 'dropoff'; place: string }
  | { type: 'transfer'; mode: TransferMode; minutes: number }
  | {
      type: 'stop';
      place: string;
      minutes: number;
      activities: string[];
      /** Ticket this stop includes, e.g. "Round-trip funicular". */
      included?: string;
      note?: string;
    };

export interface TourPrice {
  /** Retail price in EUR, per person or for the whole private group. */
  amount: number;
  per: 'person' | 'group';
  minTravellers: number;
  maxTravellers: number;
  /** Child price in EUR when the product has a separate one. */
  child?: number;
}

export interface TourContent {
  gygTourId: string;
  summary: string;
  description: string;
  highlights: string[];
  included: string[];
  excluded: string[];
  notSuitableFor: string[];
  bring: string[];
  knowBeforeYouGo: string[];
  /** What the voucher tells guests about pickup. */
  pickupInfo?: string;
  durationMinutes: number;
  /** Daily departures, 24-hour "HH:MM". */
  startTimes: string[];
  season?: string;
  price: TourPrice;
  cutoffHours: number;
  guide: 'Driver' | 'Driver-guide' | 'Host';
  languages: string[];
  cancellation: string;
  itinerary: ItineraryStep[];
  /** True when the portal has no itinerary and the steps were written from the description. */
  itineraryApproximate?: boolean;
  photos: string[];
  viatorProductCode?: string;
}

export const TOUR_CONTENT: Record<string, TourContent> = {
  "1467727": {
    "gygTourId": "1467727",
    "summary": "Travel privately from Salzburg to St. Gilgen for a one-hour lakeside stop, then enjoy 2.5 hours of free time to explore UNESCO-listed Hallstatt.",
    "description": "Enjoy a relaxed seven-hour private trip from Salzburg through the beautiful Salzkammergut to St. Gilgen and UNESCO-listed Hallstatt, traveling only with your own group in a comfortable car or minivan. Your English-speaking driver provides transportation and practical local orientation. This is a private driver experience, not a traditional guided walking tour. Begin with pickup from your hotel or accommodation in Salzburg. Travel through the Alpine lake district to St. Gilgen on Lake Wolfgang. Enjoy a one-hour stop to stroll along the lakeside, see the charming village center, take photos, browse local shops, or relax at a café. Continue through the Alpine landscape to Hallstatt. On arrival, your driver will take you to selected sightseeing and photography points, help capture photos of your group, and explain the meeting location before you explore independently. Enjoy approximately 2.5 hours of free time in Hallstatt for the historic Market Square, lakeside promenade, traditional lanes, postcard viewpoint, shops, or a relaxed café stop. After your independent visit, meet your driver at the agreed location and relax during the private return journey to your accommodation in Salzburg. This experience combines a scenic one-hour stop in St. Gilgen with the freedom to discover Hallstatt at your own pace.",
    "highlights": [
      "Travel privately by car or minivan—never a shared bus—from Salzburg",
      "Enjoy a one-hour stop in St. Gilgen on beautiful Lake Wolfgang",
      "Explore Hallstatt independently with 2.5 hours of free time",
      "Discover Hallstatt’s Market Square, lakefront, lanes, and postcard viewpoint",
      "Get practical local help and photo assistance from your private driver"
    ],
    "included": [
      "Private transportation",
      "Hotel or accommodation pickup and drop-off in Salzburg",
      "Driver and local orientation to selected sightseeing points",
      "Photos taken by your driver at selected viewpoints",
      "One-hour stop in St. Gilgen",
      "2.5 hours of free time to explore Hallstatt independently"
    ],
    "excluded": [
      "Food and drinks",
      "Other optional attraction entrance fees",
      "Gratuities",
      "Personal expenses"
    ],
    "notSuitableFor": [],
    "bring": [],
    "knowBeforeYouGo": [
      "Wheelchairs and strollers are supported. Service animals are allowed. Infant seats are available; please request one when booking. This is a private driver experience, not a walking tour with historical commentary."
    ],
    "durationMinutes": 420,
    "startTimes": [
      "09:00"
    ],
    "price": {
      "amount": 450.0,
      "per": "group",
      "maxTravellers": 7,
      "minTravellers": 1
    },
    "cutoffHours": 4,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or accommodation"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 40
      },
      {
        "type": "stop",
        "place": "St. Gilgen on Wolfgangsee",
        "minutes": 60,
        "activities": [
          "Sightseeing",
          "Photo stop"
        ],
        "note": "Lakeside stroll, village centre, café"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 50
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 150,
        "activities": [
          "Walk",
          "Sightseeing",
          "Free time"
        ],
        "note": "Driver shows photo points and the meeting spot, then free time"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 90
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or accommodation"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/4b1daa5bfd3e7b4663add79b765498b3dd55233e407717520c974c6be9be4f31.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/2164fb365328577edeac0494536168068cc95466797cedfa7373b91e1d5cc28d.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/37ca730f8f846538db9b37bf6dc9c86c947ce02667e82397add6027212f3af91.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9789665139199b8e0f6aa7e5f5d29c6119f98c87d9f960260b6262a3e014407c.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/d75589b8c8efd011f3f87908a1cf61415fe6bd100f0be77dab1904606913029a.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/852bee30d3f8d16b288693d5af6003c2043a447bb133d6b48a9a13f741be0deb.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/949ca31718969f87ff6ae92f9e21e75cfe4cee2f549d00da2349266baa74799b.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/3a50a7f8c85acc0c50a90e5548e6365b46046bffa6adf21078424a4b9d6ca490.png/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or accommodation in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. We confirm pickup by phone or WhatsApp the evening before. Drop-off is at the same address."
  },
  "1468371": {
    "gygTourId": "1468371",
    "summary": "Explore Hallstatt's ancient salt heritage and the Eagle's Nest's 20th-century history in one private day, connecting two very different Alpine stories.",
    "description": "Travel privately from Salzburg to Hallstatt, the main focus of the day. Explore Market Square, the lakeside lanes, historic salt-trading houses, and the postcard viewpoint independently, then enjoy free time for lunch. Continue across the Alps to Obersalzberg and take the official mountain bus and brass elevator to the Eagle's Nest, with admission included. Explore the building and accessible viewpoints independently. Your driver provides private transportation, practical information during the journey, and clear meeting points, but does not accompany guests or lead walking tours at either destination. The Eagle's Nest normally operates from mid-May to late October and may close because of weather or seasonal conditions. If it is closed, the activity will not operate and you will receive a full refund. Return to Salzburg in the evening after experiencing Hallstatt's ancient salt heritage and Obersalzberg's 20th-century history.",
    "highlights": [
      "Make Hallstatt's salt heritage the central chapter of the day",
      "Explore Hallstatt independently before generous free time",
      "Contrast ancient Alpine culture with Obersalzberg's 20th-century history",
      "Ride the official Eagle's Nest mountain bus and historic brass elevator",
      "Follow a Rossfeld and Obersalzberg alternative during seasonal closures"
    ],
    "included": [
      "Private air-conditioned vehicle for your group only",
      "Eagle's Nest mountain bus and lift tickets for every booked traveler",
      "English-, German-, or Arabic-speaking driver",
      "Independent exploration time in Hallstatt",
      "Practical historical background during the journey and clear meeting points",
      "Hotel or address pickup and drop-off in Salzburg city",
      "Bottled water",
      "Child seat on request",
      "Parking, tolls, and taxes"
    ],
    "excluded": [
      "Optional Documentation Center admission, if chosen",
      "Food and drinks",
      "Gratuities",
      "Personal expenses"
    ],
    "notSuitableFor": [
      "People with mobility impairments"
    ],
    "bring": [
      "Passport or ID card",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "Bring a valid passport or national ID because the tour enters Germany. This is a private driving tour with independent visits, not an accompanied or guided walking tour. The driver provides private transportation, practical information during the journey, and clear meeting points, then remains with the vehicle while guests explore Hallstatt and the Eagle's Nest independently. Eagle's Nest normally operates from mid-May to late October and may close because of bad weather. If it is closed, you receive a full refund. Mountain-bus and lift tickets are included for every booked traveler. Uneven mountain paths require comfortable shoes, and infant seats are available on request."
    ],
    "durationMinutes": 555,
    "startTimes": [
      "07:30"
    ],
    "price": {
      "amount": 300.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or address"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 80
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 180,
        "activities": [
          "Free time",
          "Sightseeing",
          "Walk"
        ],
        "note": "Market Square, salt-trading houses, postcard viewpoint, lunch"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 90
      },
      {
        "type": "stop",
        "place": "Eagle's Nest (Kehlsteinhaus)",
        "minutes": 165,
        "activities": [
          "Visit",
          "Sightseeing",
          "Walk"
        ],
        "included": "Eagle's Nest mountain bus & brass elevator",
        "note": "Seasonal (mid-May to late October); full refund if closed. Passport needed (Germany)."
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 40
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or address"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/8cb27d60ccb488d871cf10db160320d39b3cc5a0027063586203cfec0ded0b24.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/297726347df0bb3134c0eecf3332f099545e386843482dc32a8c16385c475081.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/70ab05742eb70c23f8c7606f90a280cff7101bd337c2f6646c6b7298bf6fd7b9.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/569e1fbcd5427e1b802d7285c0e729ff7ebe4329f65340fcf9133a63d1c9063b.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/8b3498f74f6d183bc3075e4cd1bbfb59a223c1f1b6745526f684bd3b606f3c16.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/59dd0823eacd42287459be1234bbdc1430928e1efaf57c12d403ff7379913174.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address anywhere in Salzburg city, approximately 15 minutes before the selected start time. Bring your passport or ID. Please send us a phone number or WhatsApp so we can confirm your pickup and attraction status the evening before."
  },
  "1468375": {
    "gygTourId": "1468375",
    "summary": "Travel privately from Salzburg to Kitzsteinhorn’s TOP OF SALZBURG at 3,029 metres, with round-trip cable-car tickets included, then unwind beside Lake Zell in Zell am See.",
    "description": "Begin your private alpine day trip with pickup directly from your Salzburg hotel or accommodation. Relax on the scenic drive through the Salzach Valley to the Kitzsteinhorn valley station in Kaprun.\n\nYour driver helps you reach the correct departure point and remains with the vehicle while you explore the mountain independently. Use your included round-trip cable-car ticket to travel through several alpine zones to TOP OF SALZBURG at 3,029 metres. Allow approximately four hours for the complete mountain experience, including the ascent and descent.\n\nAt the top, visit the panoramic platforms overlooking Hohe Tauern National Park, walk through the National Park Gallery, and experience Cinema 3000. During July and August, the seasonal ICE ARENA may also be available. Take time for photographs and, if you wish, purchase a snack or lunch at the mountain restaurant. Cable cars and mountain facilities are operated by the official Kitzsteinhorn staff; this is a self-guided visit.\n\nAfter returning to the valley, meet your driver and continue to Zell am See. Enjoy approximately 90 minutes of free time to explore the historic pedestrian centre, walk along the Lake Zell promenade, shop, or relax in a café. A boat cruise is optional when seasonal schedules allow and is not included.\n\nFinish with a comfortable return journey and drop-off at your Salzburg accommodation. Your included TOP OF SALZBURG round-trip cable-car ticket is arranged for every confirmed booking. If access to TOP OF SALZBURG unexpectedly cannot be provided, guests may choose an alternative itinerary or receive a full refund.",
    "highlights": [
      "Ride to TOP OF SALZBURG at 3,029 metres with cable-car tickets included",
      "Explore panoramic platforms, National Park Gallery, and Cinema 3000",
      "Enjoy 90 minutes in Zell am See’s old town and lakeside promenade",
      "Travel privately from your Salzburg accommodation in a comfortable vehicle",
      "Visit Kitzsteinhorn first for more time in the high-alpine scenery"
    ],
    "included": [
      "Private air-conditioned vehicle for your group only",
      "English-, German-, or Arabic-speaking driver",
      "Salzburg hotel or accommodation pickup and drop-off",
      "One TOP OF SALZBURG round-trip cable-car ticket per booked participant",
      "Panoramic platforms, National Park Gallery, and Cinema 3000",
      "Seasonal ICE ARENA access when operating",
      "Bottled water and umbrellas",
      "Child seat on request",
      "Parking, road tolls, and taxes"
    ],
    "excluded": [
      "Optional Zell am See boat cruise ticket",
      "Food and drinks",
      "Gratuities",
      "Personal expenses"
    ],
    "notSuitableFor": [],
    "bring": [],
    "knowBeforeYouGo": [
      "A TOP OF SALZBURG round-trip cable-car ticket is included and arranged for every confirmed booking. Cable cars and mountain facilities are operated by official Kitzsteinhorn staff, and the mountain visit is self-guided. If access to TOP OF SALZBURG unexpectedly cannot be provided, guests may choose an alternative itinerary or receive a full refund. Bring warm clothing, sturdy closed shoes, sunglasses, and sunscreen, even in summer. The air is thinner at 3,029 metres; take breaks when needed. Most attractions are barrier-free, but snow or gravel may affect some transfer paths. Please notify us in advance about wheelchairs, strollers, or child-seat requirements. The optional Zell am See boat cruise and food are not included."
    ],
    "durationMinutes": 570,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 350.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 1
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or accommodation"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 100
      },
      {
        "type": "stop",
        "place": "Kitzsteinhorn – TOP OF SALZBURG (3,029 m)",
        "minutes": 240,
        "activities": [
          "Cable car ride",
          "Photo stop",
          "Visit"
        ],
        "included": "TOP OF SALZBURG round-trip cable car",
        "note": "Panorama platforms, National Park Gallery, Cinema 3000; driver waits in Kaprun"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 30
      },
      {
        "type": "stop",
        "place": "Zell am See",
        "minutes": 90,
        "activities": [
          "Free time",
          "Walk",
          "Shopping"
        ],
        "note": "Pedestrian centre and Lake Zell promenade"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 90
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or accommodation"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/c6fa93986b6fccd96c0e62dc5ea4d9ccd252c0a7df3cd41575a324a5e65e7ac5.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/616ebad0c6cd48df97285f52ad3e3865b1a8f8dd39bb95cff0ccad86d72a947a.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/001b9be1ab266c6922fba3c363ffe7b19e0349ace64c129e145eb89f2167ea38.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9d4488f6539dfcf1dac5b52f9c5d5f6215ac6028040ddfb44f2064c622e7299a.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/0898076e596ffc20019d238d41eab2eff3b37fb85891cbe40229bcabf671895b.png/145.jpg"
    ],
    "pickupInfo": "Your driver will meet you at the main entrance of your Salzburg hotel or accommodation at the booked start time. Please be ready 10 minutes early and keep your phone available. Your TOP OF SALZBURG round-trip cable-car ticket is included. Return drop-off is at the same Salzburg address unless agreed otherwise."
  },
  "1477374": {
    "gygTourId": "1477374",
    "summary": "Explore Fuschlsee, St. Gilgen, Hallstatt, and Gosausee by private car or minivan, with scenic stops and independent free time at each destination.",
    "description": "Discover the highlights of Austria’s Salzkammergut on an eight-hour private driving tour created exclusively for your group. This is a private driving experience, not a guided walking tour. Your driver provides comfortable transportation, practical local tips, scenic-stop coordination, and clear meeting points while you explore each destination independently.\n\nBegin with pickup from your hotel or address in Salzburg and travel by comfortable private car or minivan. Stop at Fuschlsee to enjoy the emerald water and mountain scenery, then continue to St. Gilgen on Wolfgangsee for free time along the lakeside and in the village center.\n\nTravel onward through the Alpine landscape to UNESCO-listed Hallstatt. Enjoy independent time to explore the lakeside promenade, Market Square, traditional lanes, parish church area, and famous postcard viewpoint. Use your time for lunch, shopping, photography, or an optional attraction of your choice.\n\nContinue to Gosausee, a spectacular mountain lake beneath the Dachstein glacier and dramatic Gosaukamm peaks. Enjoy the lakeside scenery and a final photo stop before returning privately to Salzburg.\n\nThe route may be adjusted for traffic, weather, seasonal access, and local conditions. Optional attractions and entrance tickets are not included.",
    "highlights": [
      "Explore four Alpine lake destinations in one private day",
      "Enjoy independent free time in St. Gilgen and Hallstatt",
      "See Hallstatt’s famous lakeside sights at your own pace",
      "Visit Fuschlsee, Wolfgangsee, Hallstatt, and Gosausee in one day",
      "Enjoy hotel pickup and a private vehicle reserved only for your group"
    ],
    "included": [
      "Private eight-hour driving tour for your group only",
      "English-, German-, or Arabic-speaking driver",
      "Practical local tips and clear meeting-point coordination",
      "Independent free time at Fuschlsee, St. Gilgen, Hallstatt, and Gosausee",
      "Private air-conditioned car or minivan",
      "Hotel or address pickup and drop-off in Salzburg",
      "Bottled water",
      "Parking fees, tolls, and taxes"
    ],
    "excluded": [
      "Food and drinks",
      "Entrance tickets for optional attractions, including the Bone House, funicular, Skywalk, or lake boat",
      "Gratuities",
      "Personal expenses"
    ],
    "notSuitableFor": [
      "Children under 4 years"
    ],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "This is a private driving tour, not a guided walking tour. Your driver provides transportation, practical local tips, scenic-stop coordination, and clear meeting points. Guests explore Fuschlsee, St. Gilgen, Hallstatt, and Gosausee independently. Hallstatt includes cobbled lanes, inclines, and some steps. Wheelchairs and strollers are supported with advance notice so the route and vehicle space can be adjusted. Wear comfortable shoes and bring clothing suitable for changing Alpine weather. Optional attraction tickets, food, and drinks are not included. The itinerary may be adjusted for traffic, weather, or seasonal access."
    ],
    "durationMinutes": 480,
    "startTimes": [
      "08:00",
      "09:00",
      "10:00"
    ],
    "price": {
      "amount": 250.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 1
    },
    "cutoffHours": 8,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or address"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 35
      },
      {
        "type": "stop",
        "place": "Fuschlsee",
        "minutes": 20,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ],
        "note": "Emerald lake and mountain views"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 15
      },
      {
        "type": "stop",
        "place": "St. Gilgen on Wolfgangsee",
        "minutes": 35,
        "activities": [
          "Sightseeing",
          "Free time"
        ],
        "note": "Lakeside promenade and village centre"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 50
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 150,
        "activities": [
          "Free time",
          "Sightseeing"
        ],
        "note": "Promenade, Market Square, parish church area, postcard viewpoint, lunch"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 30
      },
      {
        "type": "stop",
        "place": "Gosausee (Dachstein)",
        "minutes": 35,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ],
        "note": "Lake beneath the Dachstein glacier and Gosaukamm"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 80
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or address"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/4bab2cb3b8f7caf6a7354e45d542c972f8b5efc349d68fc23ab527141a6f97f6.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/2f7acb016456c42af2d7ba68f66ba17f4fcfb8805888e676476a5550f2df1c57.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/3a50a7f8c85acc0c50a90e5548e6365b46046bffa6adf21078424a4b9d6ca490.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/852bee30d3f8d16b288693d5af6003c2043a447bb133d6b48a9a13f741be0deb.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/d75589b8c8efd011f3f87908a1cf61415fe6bd100f0be77dab1904606913029a.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/6f7a6309fbad647de078e47a5f416b31231c9c882d85954807a86d98e77f7810.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9ae4e5248807cb8d0dd51c2077caf14742ead838f24279086e7a29ec950aaaba.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/33fc8156f2972b22a046b822da975cb894d074f47c3d7a7edd1d1208f6f3c3ec.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/99fcdb27997422e1ba234cceabdbd29eb32bafbe187bb62ac9086f12cd5a66f1.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/d2d9cd760be1c47b63d9ce77f1df24fa72383a18c4cfd5e47712f59f405ac21f.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/e77b48eaa9ca58108cb8774866d5fe418ea0ada08fc46e547484cef119adc56c.jpg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address anywhere in Salzburg city, approximately 15 minutes before the selected start time. Return is to the same place. Please send us a phone number or WhatsApp so we can confirm your pickup the evening before.",
    "viatorProductCode": "5701099P1"
  },
  "1478630": {
    "gygTourId": "1478630",
    "summary": "Discover Hallstatt as the main highlight of a private heritage day, then connect its salt-world story with imperial Bad Ischl and lakeside St. Wolfgang.",
    "description": "Travel privately from Salzburg into the Salzkammergut for a day built around Hallstatt and the region that shaped it. In Hallstatt, your driver provides practical local orientation before you explore Market Square, the lakeside lanes, historic salt-trading houses, and the postcard viewpoint independently. Enjoy generous free time for lunch, photography, or an optional attraction of your choice. Continue to Bad Ischl for an independent visit around the spa quarter, the exterior of the Kaiservilla grounds, and landmarks connected with Emperor Franz Joseph and Empress Elisabeth. Finish in St. Wolfgang with free time along the lakefront and in the pilgrimage-village center, where you can see the exterior of the famous church and browse local shops. Return to Salzburg by the scenic Wolfgangsee road. This is a private driving tour, not a guided walking tour. Your driver provides transportation, practical local tips, and agreed meeting points while you explore each destination independently. Any optional museum, Kaiservilla, or church admission is not included unless stated in the selected option.",
    "highlights": [
      "Make Hallstatt the centerpiece of a private Salzkammergut heritage day",
      "Explore Hallstatt independently with generous free time",
      "Discover Bad Ischl’s imperial landmarks at your own pace",
      "Enjoy free time in St. Wolfgang beside Wolfgangsee",
      "Travel privately through the Salzkammergut with convenient hotel pickup"
    ],
    "included": [
      "Private car or minivan",
      "Salzburg hotel or apartment pickup and drop-off",
      "English, German, or Arabic-speaking driver",
      "Practical local tips and meeting-point coordination",
      "Independent time in Hallstatt, Bad Ischl, and St. Wolfgang",
      "Bottled water",
      "Parking, tolls, and taxes",
      "Infant or child seats on request"
    ],
    "excluded": [
      "Food and drinks",
      "Optional attraction admission, including Kaiservilla or museums, paid onsite if chosen",
      "Gratuities"
    ],
    "notSuitableFor": [],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "Optional attractions are paid separately",
      "Support for wheelchairs, strollers and service animals with advance notice",
      "Seasonal access"
    ],
    "durationMinutes": 480,
    "startTimes": [
      "09:00"
    ],
    "price": {
      "amount": 420.0,
      "per": "group",
      "maxTravellers": 7,
      "minTravellers": 1
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or apartment"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 80
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 180,
        "activities": [
          "Free time",
          "Sightseeing",
          "Walk",
          "Photo stop"
        ],
        "note": "Market Square, salt-trading houses, postcard viewpoint, lunch"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 20
      },
      {
        "type": "stop",
        "place": "Bad Ischl",
        "minutes": 45,
        "activities": [
          "Walk",
          "Visit",
          "Free time"
        ],
        "note": "Spa quarter and Kaiservilla grounds (exterior)"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 20
      },
      {
        "type": "stop",
        "place": "St. Wolfgang",
        "minutes": 45,
        "activities": [
          "Free time",
          "Sightseeing",
          "Walk"
        ],
        "note": "Lakefront and pilgrimage church (exterior)"
      },
      {
        "type": "transfer",
        "mode": "car",
        "minutes": 60
      },
      {
        "type": "dropoff",
        "place": "Salzburg via the Wolfgangsee road"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/d75589b8c8efd011f3f87908a1cf61415fe6bd100f0be77dab1904606913029a.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/277549e03dfce3c70d7471ca69f98f77b5a9b84c8f44866e9d964d255e1c64ba.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/4b1daa5bfd3e7b4663add79b765498b3dd55233e407717520c974c6be9be4f31.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/949ca31718969f87ff6ae92f9e21e75cfe4cee2f549d00da2349266baa74799b.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9789665139199b8e0f6aa7e5f5d29c6119f98c87d9f960260b6262a3e014407c.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/37ca730f8f846538db9b37bf6dc9c86c947ce02667e82397add6027212f3af91.png/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. We confirm pickup by phone or WhatsApp the evening before. Drop-off is at the same address."
  },
  "1478631": {
    "gygTourId": "1478631",
    "summary": "Travel privately from Salzburg to Hallstatt with funicular, Skywalk, and Salt Mine tickets included. Join the official underground tour, then enjoy free time in the lakeside village.",
    "description": "Begin with pickup from your hotel or accommodation in Salzburg and travel through the Salzkammergut in a private car or minivan. This is a private driving tour: your driver shares local tips, insights, and recommendations on the way and takes care of all timing, while you explore each stop at your own pace.\n\nOn arrival in Hallstatt, your included combination ticket gives you round-trip travel on the Hallstatt funicular, access to the World Heritage Skywalk, and admission to the Hallstatt Salt Mine. Ride the funicular to the high valley and enjoy panoramic views from the Skywalk over Hallstatt, the lake, and the surrounding Alps.\n\nContinue on foot for approximately 15 minutes to the Salt Mine entrance. Your Salt Mine ticket has a fixed entry time, which your driver confirms when you arrive. The underground experience is conducted by the official Salzwelten Hallstatt attraction staff. Put on the provided miners' clothing and follow the official guided route through historic tunnels, miners' slides, multimedia displays, and the underground salt lake before leaving the mountain by mine train. The guided mine tour lasts approximately 90 minutes; allow around three hours for the complete funicular, Skywalk, and Salt Mine visit.\n\nBack in the village, enjoy free time to explore Hallstatt at your own pace, with your driver's recommendations for lunch, the lakefront, Market Square, and the best photo spots.\n\nMeet your driver at the agreed meeting point for the private return journey to Salzburg and drop-off at your accommodation.\n\nThe included combination tickets are arranged for every confirmed booking. If the funicular, Skywalk, or Salt Mine unexpectedly cannot operate and the included visit cannot be provided, guests will receive a full refund. The Salt Mine is open only to children aged four and over and is not wheelchair accessible. The visit includes an approximately two-kilometre underground walking route. Wear sturdy, comfortable shoes and bring warm clothing, as the mine remains around 8°C throughout the year.",
    "highlights": [
      "Enjoy a private 8.5-hour trip from Salzburg with hotel pickup and drop-off",
      "Ride the Hallstatt funicular with round-trip tickets included",
      "Admire Alpine views from the World Heritage Skywalk",
      "Explore the Salt Mine with the official guide and admission included",
      "Enjoy free time in Hallstatt's historic lakeside village"
    ],
    "included": [
      "Private transportation by car or minivan",
      "Pickup and drop-off at Salzburg accommodation",
      "Private driver with local tips and recommendations",
      "Round-trip Hallstatt funicular ticket",
      "World Heritage Skywalk access",
      "Hallstatt Salt Mine admission ticket",
      "Official guided underground tour by Salzwelten Hallstatt staff",
      "Bottled water",
      "Parking, tolls, and taxes",
      "Child seats on request"
    ],
    "excluded": [
      "Food and drinks",
      "Gratuities",
      "Personal expenses",
      "Licensed tour guide (the Salt Mine tour is led by official mine staff)"
    ],
    "notSuitableFor": [
      "People with mobility impairments"
    ],
    "bring": [
      "Warm clothing",
      "Closed-toe shoes"
    ],
    "knowBeforeYouGo": [
      "Round-trip funicular travel, World Heritage Skywalk access, and Salt Mine admission are included. The underground mine tour is conducted only by official Salzwelten Hallstatt staff. Children under 4 years cannot enter the Salt Mine. The mine is not wheelchair accessible and requires approximately 2 kilometres of walking, including slopes and steps. Wear closed, sturdy, comfortable shoes and bring warm clothing; the mine remains around 8°C. Tickets are arranged for every confirmed booking. If the funicular, Skywalk, or Salt Mine unexpectedly cannot operate and the included visit cannot be provided, guests will receive a full refund.",
      "Salt Mine tickets have a fixed entry time. Your driver confirms your entry time and a clear return meeting point when you arrive in Hallstatt. From the funicular top station, allow about 15 minutes of walking, partly uphill, past the Skywalk to the mine entrance."
    ],
    "durationMinutes": 510,
    "startTimes": [
      "09:00"
    ],
    "price": {
      "amount": 310.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 1
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or accommodation"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 90
      },
      {
        "type": "transfer",
        "mode": "cable car",
        "minutes": 10
      },
      {
        "type": "stop",
        "place": "World Heritage Skywalk",
        "minutes": 30,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ],
        "included": "Salzbergbahn funicular & Skywalk"
      },
      {
        "type": "stop",
        "place": "Hallstatt Salt Mine",
        "minutes": 150,
        "activities": [
          "Guided tour",
          "Visit"
        ],
        "included": "Salt Mine admission & official guided tour",
        "note": "~15 min walk from the Skywalk; 8 °C underground, closed shoes; no children under 4"
      },
      {
        "type": "stop",
        "place": "Hallstatt village",
        "minutes": 90,
        "activities": [
          "Free time",
          "Shopping"
        ],
        "note": "Lunch, lakefront, Market Square"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 90
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or accommodation"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/3c5821a4ed45fd9e243392c6ef3f0a0af2573130c8576ceefaabeb131abc3410.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/949ca31718969f87ff6ae92f9e21e75cfe4cee2f549d00da2349266baa74799b.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/4b1daa5bfd3e7b4663add79b765498b3dd55233e407717520c974c6be9be4f31.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9789665139199b8e0f6aa7e5f5d29c6119f98c87d9f960260b6262a3e014407c.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/d75589b8c8efd011f3f87908a1cf61415fe6bd100f0be77dab1904606913029a.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/c0087940010ee99bed0aeaa5ff8b9cd522df449413b8f86764894c27e67d0d81.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/c9a093a027a1fabb52eabe90d6d74e346c701a86b13663e5e6c4ad225d5f795f.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/1b31844aa2da0c5a9fdc22dde12b66ec4ba4f4f51b3f308d6d1ced4772ab70fb.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/e0dd9fe63f48ea5c621e49ff2c94662ffb275a1f3adbd056e4a575a971085698.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/17c1eb9bd3e76611be98177b36a1e06b8ebaac970de3ec6008dc0e642619deb8.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/f3fa5da9e1e9e56e5dcfeb0b05a2efe3aa5ff545631e0ac5e843dfb0710b127e.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/572056b5e2034ca1b4df728206d9aee865259368f3217309031e506cf0e8d9a4.jpeg/145.jpg"
    ],
    "pickupInfo": "Your round-trip funicular, World Heritage Skywalk and Hallstatt Salt Mine tickets are included. Salt Mine tickets are for a fixed entry time, which your driver confirms when you arrive in Hallstatt. Allow about 15 minutes of walking, partly uphill, from the funicular top station past the Skywalk to the mine entrance. After your visit, meet your driver at the agreed meeting point and time; save the driver's WhatsApp number. The underground tour is run by official Salzwelten Hallstatt staff. Please wear closed, sturdy shoes and bring warm clothing."
  },
  "1482249": {
    "gygTourId": "1482249",
    "summary": "Discover Salzburg, Hallstatt, and the Alpine Lakes on a private day trip from Munich. Your driver shares local tips while you enjoy free time and scenic photo stops at each destination.",
    "description": "Begin with pickup from your hotel in Munich and travel in a comfortable private van with a professional driver who shares local tips, insights, and recommendations along the way. This is a private driving tour: you explore each stop at your own pace.\n\nIn Salzburg, enjoy two hours of free time in the UNESCO-listed Old Town. Your driver suggests a route through the historic lanes, Getreidegasse, Mozart’s Birthplace (Mozart Geburtshaus), and the Salzburg Cathedral area, with views of Hohensalzburg Fortress.\n\nContinue by van to Fuschlsee for a 20-minute photo stop, then drive about 15 minutes to St. Gilgen for 35 minutes beside Wolfgangsee. Continue about 50 minutes to Hallstatt and spend 2.5 hours exploring the lakeside promenade, Market Square, traditional lanes, parish church area, and famous postcard viewpoint, with time for lunch and shopping. Your driver recommends the best spots and agrees a clear meeting point before you set off.\n\nContinue about 20 minutes to the Dachstein/Gosausee area for a 35-minute photo stop and a short walk beneath the Dachstein mountains. Then return by private van to Munich, travelling through Salzburg, and drop-off at your original Munich pickup location.",
    "highlights": [
      "Explore Salzburg, Hallstatt, and the Alpine Lakes on a private day trip",
      "Explore Salzburg's UNESCO-listed Old Town at your own pace",
      "Admire the lakeside promenade and Market Square in Hallstatt",
      "Enjoy a photo stop at Fuschlsee and a walk beside Wolfgangsee",
      "Travel in a private van with a driver who shares local tips"
    ],
    "included": [
      "Private full-day tour in a comfortable van",
      "Hotel pickup and drop-off in Munich",
      "Professional driver with local tips and recommendations",
      "Free time in Salzburg Old Town and Hallstatt",
      "Photo stops at Fuschlsee, St. Gilgen, and Gosausee"
    ],
    "excluded": [
      "Food and drinks",
      "Gratuities",
      "Optional attraction entrance tickets",
      "Licensed tour guide"
    ],
    "notSuitableFor": [],
    "bring": [
      "Weather-appropriate clothing",
      "Passport or ID card",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "This is a private driving tour, not a guided tour. Your driver shares local tips and recommendations, and you explore each stop independently.",
      "The tour lasts approximately 13 hours.",
      "The route may be adjusted for traffic, weather, seasonal access, and local conditions.",
      "Guests should bring a passport or ID, comfortable walking shoes, and clothing suitable for changing Alpine weather.",
      "The route includes walking on cobbled lanes, inclines, and some steps."
    ],
    "durationMinutes": 780,
    "startTimes": [
      "07:00"
    ],
    "price": {
      "amount": 598.8,
      "per": "person",
      "maxTravellers": 8,
      "minTravellers": 1
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Munich hotel"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 105
      },
      {
        "type": "stop",
        "place": "Salzburg Old Town",
        "minutes": 120,
        "activities": [
          "Walk",
          "Free time"
        ],
        "note": "Getreidegasse, Mozart’s Birthplace, Cathedral, fortress views"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 30
      },
      {
        "type": "stop",
        "place": "Fuschlsee",
        "minutes": 20,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ]
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 15
      },
      {
        "type": "stop",
        "place": "St. Gilgen on Wolfgangsee",
        "minutes": 35,
        "activities": [
          "Walk",
          "Sightseeing"
        ]
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 50
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 150,
        "activities": [
          "Walk",
          "Free time"
        ],
        "note": "Free time for the village, lunch and shopping"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 20
      },
      {
        "type": "stop",
        "place": "Gosausee (Dachstein)",
        "minutes": 35,
        "activities": [
          "Photo stop",
          "Walk"
        ]
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 160
      },
      {
        "type": "dropoff",
        "place": "Munich pickup location"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/9ae4e5248807cb8d0dd51c2077caf14742ead838f24279086e7a29ec950aaaba.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/33fc8156f2972b22a046b822da975cb894d074f47c3d7a7edd1d1208f6f3c3ec.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/99fcdb27997422e1ba234cceabdbd29eb32bafbe187bb62ac9086f12cd5a66f1.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/4bab2cb3b8f7caf6a7354e45d542c972f8b5efc349d68fc23ab527141a6f97f6.jpg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address in Munich city at the booked start time (7:00). Please wait at the main entrance and keep your phone on. Bring a passport or ID, as the tour crosses into Austria. We confirm pickup by phone or WhatsApp the evening before. Drop-off is at the same Munich address."
  },
  "1486364": {
    "gygTourId": "1486364",
    "summary": "Combine three experiences in one private day from Salzburg: Swarovski Crystal Worlds, free time in Innsbruck's Old Town, and the Nordkette ascent. Admission and mountain tickets are included.",
    "description": "Begin with pickup from your Salzburg accommodation and travel privately through Alpine scenery toward Tyrol, with your driver sharing local tips and insights along the way. Pause for a scenic photo stop before continuing to Swarovski Crystal Worlds in Wattens. With admission included, explore the Chambers of Wonder, Crystal Dome, Giant garden, and art installations for approximately 90 minutes. The museum visit is self-guided.\n\nContinue to Innsbruck, where your driver drops you in the imperial Old Town with recommendations for the best route past Maria-Theresien-Straße, St. Anne’s Column, the Golden Roof, and historic façades, plus tips for lunch. Explore at your own pace.\n\nThe defining third stage of the itinerary is the Nordkette mountain experience. Rather than returning directly after Innsbruck, take the funicular and cable cars above the city with a round-trip mountain ticket included. Allow approximately two hours for the ascent, panoramic viewpoints over Innsbruck and the Inn Valley, and the descent.\n\nRejoin your private vehicle and return through the Alps to your Salzburg accommodation. This private three-part day combines crystal art, Innsbruck's Old Town, and a high-Alpine mountain ascent.",
    "highlights": [
      "Combine Swarovski, Innsbruck Old Town, and Nordkette in one private day",
      "Explore Innsbruck's Old Town with your driver's local tips",
      "Ride Nordkette after the city visit with round-trip tickets included",
      "Visit Swarovski Crystal Worlds with admission included",
      "Take in sweeping views over Innsbruck and the Inn Valley from Nordkette"
    ],
    "included": [
      "Private hotel pickup and drop-off in Salzburg",
      "Private transportation in a comfortable air-conditioned vehicle",
      "Private driver with local tips and recommendations",
      "Free time in Innsbruck Old Town",
      "Swarovski Crystal Worlds admission ticket",
      "Nordkette round-trip funicular and cable-car ticket",
      "Bottled water",
      "Parking fees and road tolls"
    ],
    "excluded": [
      "Lunch, food, and additional drinks",
      "Personal expenses",
      "Gratuities",
      "Licensed tour guide"
    ],
    "notSuitableFor": [
      "People with mobility impairments"
    ],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "The route timing may vary with traffic and attraction operating conditions. Innsbruck Old Town includes walking on cobbled streets. This is a private driving tour: the Swarovski museum and Innsbruck Old Town are explored independently, with tips and recommendations from your driver. Nordkette access and the level reached depend on weather and cable-car operations. If Nordkette access or the planned level is unavailable due to weather or cable-car operations, travelers will receive a full refund for the affected booking."
    ],
    "durationMinutes": 630,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 420.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or accommodation"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 120
      },
      {
        "type": "stop",
        "place": "Swarovski Crystal Worlds (Wattens)",
        "minutes": 90,
        "activities": [
          "Visit",
          "Self-guided"
        ],
        "included": "Swarovski Crystal Worlds admission",
        "note": "Chambers of Wonder, Crystal Dome, Giant garden"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 20
      },
      {
        "type": "stop",
        "place": "Innsbruck Old Town",
        "minutes": 120,
        "activities": [
          "Walk",
          "Free time"
        ],
        "note": "Maria-Theresien-Straße, St. Anne’s Column, Golden Roof, lunch"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 10
      },
      {
        "type": "stop",
        "place": "Nordkette",
        "minutes": 120,
        "activities": [
          "Cable car ride",
          "Photo stop"
        ],
        "included": "Nordkette funicular & cable cars (round trip)",
        "note": "Level reached depends on weather; full refund if unavailable"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 120
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or accommodation"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/6b86ed95707ae8d65b952464f0e0d1a9ecd616511f878f88a173f41c46c36d9a.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/ae53c8910c879b078c7fc839153b417ade9710bbd4fdc1f1041b45eed9e25c38.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/72c822863db7668153723b481ae8c439577768d319d8e22a834ecf90bf614e41.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/528c968cd70a4e7bfa303c54ba25b4a265f500777e64be480b17e2144c3bc71a.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/4482b17d5acc72adbf9837cd6eec080ab2760736bc1445ff0740d5fa9abbdc51.jpg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. Swarovski Crystal Worlds admission and the Nordkette funicular and cable-car tickets are included and handed over by your driver. We confirm pickup by phone or WhatsApp the evening before."
  },
  "1486803": {
    "gygTourId": "1486803",
    "summary": "Explore Eagle's Nest and Obersalzberg on a private WWII-history day trip with an English, German, or Arabic-speaking driver, plus Berchtesgaden and Königssee.",
    "description": "Begin your private day with pickup from your Salzburg hotel at 8:00 AM in a comfortable private car or minivan. On the approximately 45-minute drive into the Bavarian Alps, your English-, German-, or Arabic-speaking driver shares local tips and background on the Obersalzberg region.\n\nAt the Eagle's Nest departure point, the official mountain bus and historic brass elevator tickets are included for every booked guest. Explore the summit, terraces, and panoramic views at your own pace.\n\nContinue to Documentation Obersalzberg, where admission is included. The official exhibition covers dictatorship, persecution, war, genocide, and the Nazi leadership's use of Obersalzberg, including accessible parts of the historic bunker system.\n\nThen enjoy free time in Berchtesgaden Old Town, with lunch at your own expense, followed by a stop at Königssee, where your driver recommends the best walk around the harbor to the Malerwinkel viewpoint for photos, before returning to Salzburg. The experience is private and paced around your group. If the included Eagle's Nest visit cannot operate, travelers will receive a full refund for the affected booking.",
    "highlights": [
      "Travel privately with an English, German, or Arabic-speaking driver",
      "Explore Eagle's Nest with included mountain bus and elevator tickets",
      "Visit Documentation Obersalzberg and the historic bunker system",
      "Enjoy free time in Berchtesgaden's historic Old Town",
      "Walk along Königssee to the Malerwinkel viewpoint for photos"
    ],
    "included": [
      "Salzburg hotel pickup and drop-off",
      "Private transportation",
      "Driver speaking English, German, or Arabic, with local tips",
      "Eagle's Nest mountain bus and elevator tickets",
      "Documentation Obersalzberg admission",
      "Bottled water"
    ],
    "excluded": [
      "Lunch",
      "Food other than bottled water",
      "Optional Königssee boat cruise",
      "Licensed tour guide"
    ],
    "notSuitableFor": [],
    "bring": [
      "Jacket",
      "Passport or ID card",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "This is a private driving tour, not a guided tour. Your driver shares local tips and recommendations; the Eagle's Nest and Documentation Obersalzberg are explored independently.",
      "The Eagle's Nest is seasonal and weather dependent.",
      "If the included Eagle's Nest visit cannot operate, travelers will receive a full refund for the affected booking."
    ],
    "durationMinutes": 480,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 280.0,
      "per": "person",
      "maxTravellers": 6,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English",
      "German",
      "Arabic"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 45
      },
      {
        "type": "stop",
        "place": "Eagle's Nest (Kehlsteinhaus)",
        "minutes": 90,
        "activities": [
          "Visit",
          "Sightseeing"
        ],
        "included": "Mountain bus & elevator",
        "note": "Explored at your own pace; seasonal and weather dependent"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 10
      },
      {
        "type": "stop",
        "place": "Documentation Obersalzberg",
        "minutes": 60,
        "activities": [
          "Museum visit"
        ],
        "included": "Documentation Obersalzberg admission",
        "note": "Exhibition and bunker system"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 15
      },
      {
        "type": "stop",
        "place": "Berchtesgaden Old Town",
        "minutes": 60,
        "activities": [
          "Walk",
          "Free time"
        ],
        "note": "Market Square; lunch at own expense"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 15
      },
      {
        "type": "stop",
        "place": "Königssee",
        "minutes": 60,
        "activities": [
          "Walk",
          "Photo stop"
        ],
        "note": "Harbour and Malerwinkel; boat cruise optional, not included"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 40
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/b71a0192414cfc791aba44b297bec0f60375bfe9121c875052fd03145b7a0b4d.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/8dd99bae6b5b522e11f562b176edfcfc9433a058bc4afe15727220fe1647e76d.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/cf0033c5568e2900da24735e7930658bd5620e3a20d409eb7c4f3d8c8710d677.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/0c76b19a03a3dcbb2a087667ede4570cbec9a693ab8ef8edcbe3f35022750d81.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/8b3498f74f6d183bc3075e4cd1bbfb59a223c1f1b6745526f684bd3b606f3c16.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/7186f106ce6c86b4fa8b70714fc37da3b03d3b830f7a76251eea051873df55ed.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/883404223a240aba0dd92947d07a80a0e49fecad2ec1e7159645e20dd9b720a5.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/53fa00773df2fb0a98bafa3f29477bd08a977d051de734f41567448987baea67.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/b78ffb96670b6cc61df04793a031f9cb2d712d1c674cefce708ca741722418b4.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your Salzburg hotel at the booked start time. Please wait at the main entrance and keep your phone on. Bring a passport or ID, as the tour enters Germany. Eagle's Nest bus and elevator tickets and Documentation Obersalzberg admission are included. We confirm pickup by phone or WhatsApp the evening before.",
    "season": "Bookable May 15 – Oct 31, 2027"
  },
  "1487987": {
    "gygTourId": "1487987",
    "summary": "Discover Hallstatt and Eagle's Nest on a private day trip from Linz. Enjoy a scenic drive, explore Hallstatt at your own pace, and ride the official bus and elevator to Eagle's Nest.",
    "description": "Begin your day with a convenient pickup from your accommodation in Linz. Travel through the picturesque landscapes of Upper Austria to reach the charming village of Hallstatt. Stop at a classic panoramic viewpoint for driver-assisted photographs before enjoying 3 hours of free time to explore the market square, lakeside lanes, and shops at your own pace.\n\nNext, embark on a scenic drive to the Obersalzberg departure point near Berchtesgaden. Board the official mountain bus and take the elevator journey to Eagle's Nest. Spend time at the summit, taking in the breathtaking views and capturing memorable photos.\n\nThroughout the day, your English-speaking driver-host will provide transportation, coordinate timing, and offer practical orientation. After your visit to Eagle's Nest, relax on the return journey to Linz, where you will be dropped off at your accommodation.",
    "highlights": [
      "Enjoy a private day trip from Linz to Hallstatt and Eagle's Nest",
      "Travel in comfort with a private air-conditioned vehicle and driver",
      "Explore Hallstatt's market square and lakeside lanes at your own pace",
      "Ride the official mountain bus and elevator to Eagle's Nest",
      "Capture stunning photos with the help of your driver-host"
    ],
    "included": [
      "Private air-conditioned transportation",
      "Linz hotel pickup and drop-off",
      "English-speaking driver-host",
      "Eagle's Nest official bus and elevator ticket",
      "Bottled water",
      "Parking",
      "Tolls",
      "Cross-border transportation",
      "Photo assistance"
    ],
    "excluded": [
      "Meals",
      "Guided attraction visits",
      "Hallstatt attraction tickets",
      "Personal expenses"
    ],
    "notSuitableFor": [],
    "bring": [
      "Passport or ID card"
    ],
    "knowBeforeYouGo": [
      "Planned duration: 10 hours, departing Linz at 09:00 and returning around 19:00. Allow approximately 2.5 hours of free time in Hallstatt, the longest sightseeing stop, and approximately 2 hours for the Eagle's Nest visit including its mountain bus and elevator transfers. Remaining time is for road travel, parking and timing buffers. Visit order depends on reserved mountain transport times.",
      "Every guest must carry a valid passport or accepted travel document for crossing between Austria and Germany.",
      "Eagle's Nest operates seasonally and is subject to weather and road conditions. If Eagle's Nest is closed, guests may choose a full refund for the affected booking, rescheduling, or a suitable alternative.",
      "All times are approximate and subject to traffic, queues, weather and attraction operation. This private direct departure from Linz combines Hallstatt free time with Eagle's Nest admission."
    ],
    "durationMinutes": 600,
    "startTimes": [
      "09:00"
    ],
    "price": {
      "amount": 250.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 3
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Linz accommodation"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 105
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 165,
        "activities": [
          "Photo stop",
          "Free time",
          "Sightseeing"
        ],
        "note": "Panoramic viewpoint photos first, then Market Square, lakeside lanes, shops"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 90
      },
      {
        "type": "stop",
        "place": "Eagle's Nest (Kehlsteinhaus)",
        "minutes": 120,
        "activities": [
          "Visit",
          "Sightseeing"
        ],
        "included": "Official mountain bus & elevator",
        "note": "Order may swap with Hallstatt to fit the reserved bus time. Passport needed (Germany)."
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 120
      },
      {
        "type": "dropoff",
        "place": "Linz accommodation (around 19:00)"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/0b33837dcf02c48e9e39bb3f5b39cdb7566af9c1e39b950e77ac0ed0d7f28c82.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/1723fbacc2ffa7f501cb9263ad30d7c2e861783609477610de85cd6e8ab49c00.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/a0a0fe792c9839c3ce2131dd75e2ec4f9e50cf54a60e8933fbfa87f3fb7a67f2.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/7186f106ce6c86b4fa8b70714fc37da3b03d3b830f7a76251eea051873df55ed.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address in Linz at the booked start time. Please wait at the main entrance and keep your phone on. Bring a passport or ID for the border crossing into Germany. Eagle's Nest bus and elevator tickets are included. We confirm pickup by phone or WhatsApp the evening before.",
    "season": "Bookable until Nov 8, 2026"
  },
  "1487990": {
    "gygTourId": "1487990",
    "summary": "Discover Hallstatt, Traunsee, and Gosausee on a private day trip from Linz. Explore Hallstatt at your own pace, enjoy scenic photo stops, and relax with a private driver and air-conditioned vehicle.",
    "description": "Begin your private day trip with a pickup from your accommodation in Linz. Travel in a comfortable, air-conditioned vehicle with an English-speaking driver-host who provides practical orientation, recommends scenic photo locations, and takes photos of you using your own phone.\n\nStop at Gmunden on Lake Traunsee for a waterfront photo opportunity with an exterior view of Ort Castle. Continue through the Salzkammergut to Hallstatt, where your driver will take you to a classic panoramic viewpoint for photos.\n\nEnjoy approximately 3 hours of independent time in Hallstatt to explore the market square, lakeside streets, shops, and viewpoints. Then, drive to Lake Gosau for an independent lakeside walk and photographs of the Dachstein mountain backdrop.\n\nFinally, relax on the drive back to Linz, where you’ll be dropped off at your accommodation.",
    "highlights": [
      "Discover the beauty of the Austrian Alps on a private day trip from Linz",
      "Explore the charming village of Hallstatt at your own pace",
      "Admire the stunning views of Lake Traunsee and Lake Gosau",
      "Enjoy the convenience of a private driver and air-conditioned vehicle",
      "Capture memories with the help of your driver, who will take photos for you"
    ],
    "included": [
      "Private air-conditioned transportation",
      "Linz hotel pickup and drop-off",
      "English-speaking driver-host",
      "Bottled water",
      "Parking",
      "Tolls",
      "Photo assistance"
    ],
    "excluded": [
      "Meals",
      "Boat rides",
      "Attraction admissions",
      "Guided tours",
      "Personal expenses"
    ],
    "notSuitableFor": [],
    "bring": [],
    "knowBeforeYouGo": [
      "The order of the lake stops may change because of traffic and weather.",
      "Lake Gosau walking time depends on seasonal road and weather conditions.",
      "The product is distinct because it departs from Linz and combines three different alpine lakes: Traunsee, Lake Hallstatt and Gosausee, with Hallstatt as the main stop."
    ],
    "durationMinutes": 480,
    "startTimes": [
      "09:00"
    ],
    "price": {
      "amount": 250.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 3
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Linz accommodation"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 50
      },
      {
        "type": "stop",
        "place": "Traunsee (Gmunden)",
        "minutes": 15,
        "activities": [
          "Photo stop"
        ],
        "note": "Waterfront and Schloss Ort (exterior)"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 45
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 180,
        "activities": [
          "Photo stop",
          "Free time"
        ],
        "note": "Classic panoramic viewpoint first, then independent time"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 25
      },
      {
        "type": "stop",
        "place": "Gosausee",
        "minutes": 30,
        "activities": [
          "Walk",
          "Photo stop"
        ],
        "note": "Dachstein backdrop; depends on road and weather"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 105
      },
      {
        "type": "dropoff",
        "place": "Linz accommodation"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9485279758443f7bdb70f90caacf0dd2f0c93dc326dba92975000b3ebbc4c2cf.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/46d8799593e4137de1a36fc0cee897dcc000425e889e7d82081ee4735a241ad9.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/ea86bafaeaa0f0bdd3f1661fe1f7c1359d68ed2fa7ecc9ba45ad88d7ac649fc4.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9af5800d659c17178631d5e6ec8a67d447ba2d266ae7c09b9e14169f0b6ea624.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or address in Linz at the booked start time. Please wait at the main entrance and keep your phone on. We confirm pickup by phone or WhatsApp the evening before. Drop-off is at the same address."
  },
  "1488628": {
    "gygTourId": "1488628",
    "summary": "Discover Hallstatt, Attersee, and the Red Bull HQ on a private day trip from Salzburg. Enjoy a flexible itinerary, scenic views, and the freedom to explore at your own pace.",
    "description": "Begin your private day trip with a pickup from your hotel or apartment in Salzburg. Meet your friendly driver-host, who will provide route information, local tips, and flexible assistance throughout the day.\n\nHead to the Red Bull Headquarters beside Fuschlsee for a quick 15-minute exterior photo stop. Continue through the Salzkammergut to Attersee for a 30-minute lakeside photography and scenic stop.\n\nDrive onward through alpine countryside to UNESCO-listed Hallstatt. Spend about 3 hours in Hallstatt with a brief orientation from the driver-host followed by independent time for the lakeside promenade, market square, viewpoints, shops, lunch, and photography.\n\nReturn by a scenic route to Salzburg. Enjoy the convenience of a private air-conditioned car or minivan, bottled water, and photography assistance.",
    "highlights": [
      "Enjoy a private day trip from Salzburg with a driver-host",
      "Stop at the Red Bull Headquarters for a quick photo opportunity",
      "Visit the picturesque Attersee and take in the scenic views",
      "Explore the UNESCO-listed Hallstatt at your own pace",
      "Benefit from a flexible itinerary and personalized assistance"
    ],
    "included": [
      "Private air-conditioned car or minivan",
      "Salzburg pickup and drop-off",
      "Driver-host",
      "Photography assistance",
      "Bottled water",
      "Parking",
      "Tolls",
      "Fuel"
    ],
    "excluded": [
      "Food and drinks",
      "Attraction admission",
      "Optional activities",
      "Gratuities",
      "Licensed tour guide"
    ],
    "notSuitableFor": [],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "The Red Bull stop is exterior-only.",
      "Route order may change because of traffic or weather."
    ],
    "durationMinutes": 540,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 280.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or apartment"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 35
      },
      {
        "type": "stop",
        "place": "Red Bull Headquarters (Fuschlsee)",
        "minutes": 15,
        "activities": [
          "Photo stop"
        ],
        "note": "Exterior only"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 40
      },
      {
        "type": "stop",
        "place": "Attersee",
        "minutes": 30,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ]
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 75
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 180,
        "activities": [
          "Free time",
          "Sightseeing",
          "Walk"
        ],
        "note": "Short orientation, then promenade, Market Square, lunch"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 80
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or apartment"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/59dd0823eacd42287459be1234bbdc1430928e1efaf57c12d403ff7379913174.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/92836a1f04b0844849943c6fa45d87811b6f3fb0cf090d9a5ec55d7843d93bb3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9f8427ccc200700b9eb53cabb90faa704c79a5c24e795d93bdece51e336ab6dc.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/459e1861c3613a34dc2c7156ead5c88a22c71031b14200a0b4127bc1a81758b7.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/28827383dfde3e6d0f521a48ef23fc681fcac46ed992a53b9a0e958a9d45c5f5.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9af7a0d1b0de6f4cae05c9c6a672bd6bfd83d80f342df5bcfda9de3a5ac031ca.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/859edb4f2af8936226ed873498ed462097c58e4fa2924f9e87413b74e44ec223.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/c79409ad2abb8ec2e678b887693e5528bb600eea619801706131a5e7caeb541f.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or apartment in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. We confirm pickup by phone or WhatsApp the evening before. Drop-off is at the same address."
  },
  "1488644": {
    "gygTourId": "1488644",
    "summary": "Discover Hallstatt and Mondsee on a private tour from Salzburg. Ride the Hallstatt funicular to the Skywalk, explore Hallstatt independently, and stop at Mondsee for a photo op.",
    "description": "Begin your private tour with a pickup from your hotel or apartment in Salzburg. Meet your driver-host, who will provide route information, local tips, and flexible assistance throughout the tour.\n\nTravel first to Mondsee for a 40-minute lakeside and historic town photo stop. Continue through the Salzkammergut to UNESCO-listed Hallstatt. Ride the Hallstatt funicular to the panoramic Skywalk, with round-trip funicular tickets and Skywalk access included in the price. Enjoy mountain and lake views and photography from above Hallstatt.\n\nReturn to the village and spend approximately 2.5 hours exploring independently after a short orientation from the driver-host, including the lakeside promenade, market square, shops, viewpoints, and time for lunch. Return to Salzburg by a scenic alpine route.",
    "highlights": [
      "Enjoy a private tour from Salzburg to Hallstatt and Mondsee",
      "Ride the Hallstatt funicular to the panoramic Skywalk",
      "Explore Hallstatt independently with tips from your driver-host",
      "Stop at Mondsee for a 40-minute lakeside and historic town photo stop",
      "Travel through the Salzkammergut and enjoy mountain and lake views"
    ],
    "included": [
      "Private air-conditioned car or minivan",
      "Salzburg pickup and drop-off",
      "Driver-host",
      "Photography assistance",
      "Bottled water",
      "Parking",
      "Tolls",
      "Fuel",
      "Round-trip Hallstatt funicular and Skywalk access"
    ],
    "excluded": [
      "Food and drinks",
      "Other attraction tickets",
      "Optional activities",
      "Gratuities",
      "Licensed tour guide"
    ],
    "notSuitableFor": [],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "Funicular and Skywalk operation can be affected by maintenance or weather. If the Hallstatt funicular or Skywalk is unavailable, we will provide a full refund for the entire affected booking. Any alternative viewpoint or itinerary will be offered only as an optional choice and will not replace your right to the full refund."
    ],
    "durationMinutes": 540,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 320.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or apartment"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 30
      },
      {
        "type": "stop",
        "place": "Mondsee",
        "minutes": 40,
        "activities": [
          "Photo stop",
          "Walk"
        ],
        "note": "Lakeside and historic town"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 75
      },
      {
        "type": "transfer",
        "mode": "cable car",
        "minutes": 10
      },
      {
        "type": "stop",
        "place": "World Heritage Skywalk",
        "minutes": 30,
        "activities": [
          "Photo stop",
          "Sightseeing"
        ],
        "included": "Salzbergbahn funicular & Skywalk",
        "note": "Full refund if the funicular or Skywalk is closed"
      },
      {
        "type": "stop",
        "place": "Hallstatt village",
        "minutes": 150,
        "activities": [
          "Free time",
          "Walk"
        ],
        "note": "Short orientation, then promenade, Market Square, lunch"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 90
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or apartment"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/ebbbde835468910b24702437fc37618d9efae02dfd613b697a4f481d79091411.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/f2ad2a89d2f153c7a6e19fc3165bad958a7eb3826c13b8900dcbe04ec36ffad8.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/da98b1cd9c8dcfbe161cacefc8379a7b4e314d6506b3e0f46048340e1d0390d8.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/cf061c6903f4eda6bdfc8c2d4194f5e5fd492b5767c5197bb18e5cbf43321270.jpg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/59dd0823eacd42287459be1234bbdc1430928e1efaf57c12d403ff7379913174.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/8e1e2edce839ffd722d0e6a413ca39aeb436779b3180b136b8f42c6539e324db.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/020c3d024b943942e6d88f5f1100b7292c273d04dbdba3e525cbc5651ece4fb8.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/2e23d343a6cf0c1e217ed016ee71245ced35ed36e06403049f3d7a32d281f75b.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/1a37231d09a51012a3a69dd3ab770173efd1ea131533d4f39fc4fe4b97c07ea8.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or apartment in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. Round-trip Hallstatt funicular and Skywalk tickets are included and handed over by your driver. We confirm pickup by phone or WhatsApp the evening before."
  },
  "1488651": {
    "gygTourId": "1488651",
    "summary": "Discover Hallstatt, Dachstein, and Gosausee on a private 10-hour tour from Salzburg. Enjoy free time in Hallstatt, ride the cable car to visit the 5 Fingers platform, and stop at Gosausee.",
    "description": "Begin your day with a convenient pickup from your hotel or apartment in Salzburg. Set off on a scenic drive through the Salzkammergut region to the UNESCO-listed village of Hallstatt. Upon arrival, receive a short orientation from your driver-host before enjoying 2.5 hours of free time to explore the lakeside promenade, market square, viewpoints, shops, and restaurants at your own pace.\n\nNext, head to Dachstein Krippenstein and ride the cable car into the high-alpine landscape. Walk to the famous 5 Fingers viewing platform for dramatic views over Hallstätter See and the surrounding mountains.\n\nFinish with a 40-minute lakeside photography stop at Gosausee beneath the Dachstein massif before returning to Salzburg.",
    "highlights": [
      "Explore Hallstatt, Dachstein, and Gosausee on a private day trip from Salzburg",
      "Drive through the Salzkammergut and explore Hallstatt at your own pace",
      "Ride the cable car to the 5 Fingers viewing platform for panoramic views",
      "Stop at Gosausee for a lakeside photography session beneath the Dachstein massif",
      "Benefit from a private driver-host, hotel pickup, and bottled water"
    ],
    "included": [
      "Private air-conditioned car or minivan",
      "Salzburg pickup and drop-off",
      "Driver-host",
      "Photography assistance",
      "Bottled water",
      "Parking",
      "Tolls",
      "Fuel",
      "Dachstein Krippenstein cable-car tickets for the 5 Fingers experience"
    ],
    "excluded": [
      "Food and drinks",
      "Other attraction tickets",
      "Optional activities",
      "Gratuities",
      "Licensed tour guide"
    ],
    "notSuitableFor": [],
    "bring": [
      "Weather-appropriate clothing",
      "Comfortable shoes"
    ],
    "knowBeforeYouGo": [
      "The 5 Fingers walk requires moderate walking and is subject to cable-car operation, weather, snow, and seasonal access. If the Dachstein Krippenstein cable car or 5 Fingers access is unavailable, we will provide a full refund for the entire affected booking. Any alternative route or scenic stop will be offered only as an optional choice, which you may decline."
    ],
    "durationMinutes": 600,
    "startTimes": [
      "08:00"
    ],
    "price": {
      "amount": 350.0,
      "per": "person",
      "maxTravellers": 7,
      "minTravellers": 2
    },
    "cutoffHours": 10,
    "guide": "Driver",
    "languages": [
      "English"
    ],
    "cancellation": "Free cancellation up to 24 hours before the start",
    "itinerary": [
      {
        "type": "pickup",
        "place": "Salzburg hotel or apartment"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 80
      },
      {
        "type": "stop",
        "place": "Hallstatt",
        "minutes": 180,
        "activities": [
          "Free time",
          "Sightseeing",
          "Walk"
        ],
        "note": "Short orientation, then promenade, Market Square, viewpoints"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 10
      },
      {
        "type": "transfer",
        "mode": "cable car",
        "minutes": 15
      },
      {
        "type": "stop",
        "place": "5 Fingers viewing platform (Krippenstein)",
        "minutes": 60,
        "activities": [
          "Photo stop",
          "Walk"
        ],
        "included": "Dachstein Krippenstein cable car",
        "note": "Moderate walk; weather and snow dependent, full refund if closed"
      },
      {
        "type": "transfer",
        "mode": "cable car",
        "minutes": 15
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 30
      },
      {
        "type": "stop",
        "place": "Gosausee",
        "minutes": 60,
        "activities": [
          "Photo stop",
          "Walk"
        ],
        "note": "Lakeside beneath the Dachstein massif"
      },
      {
        "type": "transfer",
        "mode": "van",
        "minutes": 80
      },
      {
        "type": "dropoff",
        "place": "Salzburg hotel or apartment"
      }
    ],
    "photos": [
      "https://cdn.getyourguide.com/img/tour/6e3535e8beefc252444a016715b01715050825ea841ddc82173190913d8dce40.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/865b0db7df47391884a3987fd47cb94854167bf0d13374a98866ee471738df8b.png/145.jpg",
      "https://cdn.getyourguide.com/img/tour/2d311d02e95e56eb752efb864955bbffde5e3412e51500e21b18d15a0b93bf94.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/91381274b5ed1023a37f631b8c18cb646b1867f41cfa02aac36c13c7a0c6a631.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/aca8a226c1f3c338b43e97ff924bd991ab491112f632f7e5e2701b28544ee399.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/bd25e9838ea330defa698c15df50cc17fdbd3e13914b49db4bafe4cac370dec7.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/bdf688883a0399ff8209606f60e468d169c5bc6b9f42ea95fbd034afa87e1201.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/46d8799593e4137de1a36fc0cee897dcc000425e889e7d82081ee4735a241ad9.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/ea86bafaeaa0f0bdd3f1661fe1f7c1359d68ed2fa7ecc9ba45ad88d7ac649fc4.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/5f4214c441cfe0964db1eef3ed5943c98f0cee82471617c6b27874896c1c50f3.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9de65beb49ee3c1e605a184fbb7bee10ded9513f02a40eb7136c49dd7f522322.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/7b29368dd4f79f5030d06cf13de673656e133536da4e155017696b302a14f51b.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/2ae0ee333b6d66272bdf31e8f71c5e3b7ba5c98bbaa1d4d9541640f2a0fb11df.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/9af5800d659c17178631d5e6ec8a67d447ba2d266ae7c09b9e14169f0b6ea624.jpeg/145.jpg",
      "https://cdn.getyourguide.com/img/tour/59dd0823eacd42287459be1234bbdc1430928e1efaf57c12d403ff7379913174.jpeg/145.jpg"
    ],
    "pickupInfo": "Pickup is from your hotel or apartment in Salzburg city at the booked start time. Please wait at the main entrance and keep your phone on. Dachstein Krippenstein cable-car tickets for the 5 Fingers platform are included and handed over by your driver. We confirm pickup by phone or WhatsApp the evening before."
  }
};
