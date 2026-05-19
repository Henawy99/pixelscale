// EG-ON Energy API Service
// Documentation: https://gateway.eg-on.com/documentation/index.html

const EGON_BASE_URL = process.env.EGON_API_BASE_URL || 'https://gateway.eg-on.com';
const EGON_TOKEN = process.env.EGON_API_TOKEN || '';

async function egonFetch(endpoint, options = {}) {
  const url = `${EGON_BASE_URL}${endpoint}`;
  const headers = {
    'Authorization': `Bearer ${EGON_TOKEN}`,
    'Content-Type': 'application/json',
    ...options.headers,
  };

  try {
    const response = await fetch(url, { ...options, headers });
    if (!response.ok) {
      throw new Error(`EG-ON API Error: ${response.status} ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('EG-ON API Error:', error);
    throw error;
  }
}

// Get available tariffs for a location
export async function getTariffs(postalCode, consumption, type = 'strom') {
  return egonFetch(`/api/tariffs?plz=${postalCode}&consumption=${consumption}&type=${type}`);
}

// Submit a contract
export async function submitContract(contractData) {
  return egonFetch('/api/contracts', {
    method: 'POST',
    body: JSON.stringify(contractData),
  });
}

// Get contract status
export async function getContractStatus(contractId) {
  return egonFetch(`/api/contracts/${contractId}/status`);
}

// Get available providers
export async function getProviders(type = 'strom') {
  return egonFetch(`/api/providers?type=${type}`);
}

export default {
  getTariffs,
  submitContract,
  getContractStatus,
  getProviders,
};
