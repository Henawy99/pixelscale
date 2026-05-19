// E-Control Tariff Calculator API Service
// Documentation: https://api-dev.e-control.at/rc-doc/
// Credentials: username=tarifo

const ECONTROL_BASE_URL = process.env.ECONTROL_API_BASE_URL || 'https://api-dev.e-control.at/rc/1.0';
const ECONTROL_USERNAME = process.env.ECONTROL_USERNAME || 'tarifo';
const ECONTROL_PASSWORD = process.env.ECONTROL_PASSWORD || '';

function getAuthHeader() {
  const credentials = btoa(`${ECONTROL_USERNAME}:${ECONTROL_PASSWORD}`);
  return `Basic ${credentials}`;
}

async function econtrolFetch(endpoint, options = {}) {
  const url = `${ECONTROL_BASE_URL}${endpoint}`;
  const headers = {
    'Authorization': getAuthHeader(),
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...options.headers,
  };

  try {
    const response = await fetch(url, { ...options, headers });
    if (!response.ok) {
      throw new Error(`E-Control API Error: ${response.status} ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('E-Control API Error:', error);
    throw error;
  }
}

// Get network costs for a postal code
export async function getNetworkCosts(postalCode, type = 'strom') {
  return econtrolFetch(`/netzkosten?plz=${postalCode}&type=${type}`);
}

// Get tariff comparison
export async function compareTariffs(postalCode, consumption, type = 'strom') {
  return econtrolFetch(`/tarife?plz=${postalCode}&verbrauch=${consumption}&sparte=${type}`);
}

// Calculate total energy costs
export async function calculateEnergyCosts(postalCode, consumption, type = 'strom') {
  try {
    const [networkCosts, tariffs] = await Promise.all([
      getNetworkCosts(postalCode, type),
      compareTariffs(postalCode, consumption, type),
    ]);
    return { networkCosts, tariffs };
  } catch (error) {
    console.error('Error calculating energy costs:', error);
    return null;
  }
}

export default {
  getNetworkCosts,
  compareTariffs,
  calculateEnergyCosts,
};
