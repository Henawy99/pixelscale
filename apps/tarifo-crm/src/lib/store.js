'use client';

import { supabase, isSupabaseConfigured } from './supabase';

// Local storage keys
const CUSTOMERS_KEY = 'tarifo_customers';
const SCHNELLCHECKS_KEY = 'tarifo_schnellchecks';
const CONTRACTS_KEY = 'tarifo_contracts';
const LEADS_KEY = 'tarifo_leads';
const COMMISSIONS_KEY = 'tarifo_commissions';

// Generic CRUD helpers for localStorage
function getStore(key) {
  if (typeof window === 'undefined') return [];
  return JSON.parse(localStorage.getItem(key) || '[]');
}

function setStore(key, data) {
  if (typeof window === 'undefined') return;
  localStorage.setItem(key, JSON.stringify(data));
}

// ============ CUSTOMERS ============
export function getCustomers() {
  return getStore(CUSTOMERS_KEY);
}

export function getCustomer(id) {
  return getStore(CUSTOMERS_KEY).find((c) => c.id === id);
}

export function saveCustomer(customer) {
  const customers = getStore(CUSTOMERS_KEY);
  if (customer.id) {
    const idx = customers.findIndex((c) => c.id === customer.id);
    if (idx !== -1) {
      customers[idx] = { ...customers[idx], ...customer, updated_at: new Date().toISOString() };
    } else {
      customers.push(customer);
    }
  } else {
    customer.id = `cust-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    customer.created_at = new Date().toISOString();
    customers.push(customer);
  }
  setStore(CUSTOMERS_KEY, customers);
  return customer;
}

export function deleteCustomer(id) {
  const customers = getStore(CUSTOMERS_KEY).filter((c) => c.id !== id);
  setStore(CUSTOMERS_KEY, customers);
}

// ============ SCHNELLCHECKS ============
export function getSchnellchecks() {
  return getStore(SCHNELLCHECKS_KEY);
}

export function getSchnellcheck(id) {
  return getStore(SCHNELLCHECKS_KEY).find((s) => s.id === id);
}

export function saveSchnellcheck(check) {
  const checks = getStore(SCHNELLCHECKS_KEY);
  if (check.id) {
    const idx = checks.findIndex((c) => c.id === check.id);
    if (idx !== -1) {
      checks[idx] = { ...checks[idx], ...check, updated_at: new Date().toISOString() };
    } else {
      checks.push(check);
    }
  } else {
    check.id = `sc-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    check.created_at = new Date().toISOString();
    check.status = check.status || 'draft';
    checks.push(check);
  }
  setStore(SCHNELLCHECKS_KEY, checks);
  return check;
}

// ============ CONTRACTS ============
export function getContracts() {
  return getStore(CONTRACTS_KEY);
}

export function getContract(id) {
  return getStore(CONTRACTS_KEY).find((c) => c.id === id);
}

export function saveContract(contract) {
  const contracts = getStore(CONTRACTS_KEY);
  if (contract.id) {
    const idx = contracts.findIndex((c) => c.id === contract.id);
    if (idx !== -1) {
      contracts[idx] = { ...contracts[idx], ...contract, updated_at: new Date().toISOString() };
    } else {
      contracts.push(contract);
    }
  } else {
    contract.id = `con-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    contract.created_at = new Date().toISOString();
    contract.status = contract.status || 'pending';
    contracts.push(contract);
  }
  setStore(CONTRACTS_KEY, contracts);
  return contract;
}

// ============ LEADS ============
export function getLeads() {
  return getStore(LEADS_KEY);
}

export function getLead(id) {
  return getStore(LEADS_KEY).find((l) => l.id === id);
}

export function saveLead(lead) {
  const leads = getStore(LEADS_KEY);
  if (lead.id) {
    const idx = leads.findIndex((l) => l.id === lead.id);
    if (idx !== -1) {
      leads[idx] = { ...leads[idx], ...lead, updated_at: new Date().toISOString() };
    } else {
      leads.push(lead);
    }
  } else {
    lead.id = `lead-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    lead.created_at = new Date().toISOString();
    lead.status = lead.status || 'new';
    leads.push(lead);
  }
  setStore(LEADS_KEY, leads);
  return lead;
}

export function deleteLead(id) {
  const leads = getStore(LEADS_KEY).filter((l) => l.id !== id);
  setStore(LEADS_KEY, leads);
}

export function importLeads(leadsArray) {
  const existing = getStore(LEADS_KEY);
  const newLeads = leadsArray.map((lead) => ({
    ...lead,
    id: `lead-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    created_at: new Date().toISOString(),
    status: lead.status || 'new',
  }));
  setStore(LEADS_KEY, [...existing, ...newLeads]);
  return newLeads;
}

// ============ COMMISSIONS ============
export function getCommissions() {
  return getStore(COMMISSIONS_KEY);
}

export function saveCommission(commission) {
  const commissions = getStore(COMMISSIONS_KEY);
  commission.id = `comm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  commission.created_at = new Date().toISOString();
  commission.status = commission.status || 'pending';
  commissions.push(commission);
  setStore(COMMISSIONS_KEY, commissions);
  return commission;
}

// ============ DASHBOARD STATS ============
export function getDashboardStats(userId, userRole) {
  const customers = getCustomers();
  const contracts = getContracts();
  const leads = getLeads();
  const checks = getSchnellchecks();
  const commissions = getCommissions();

  const isDirector = userRole === 'sales_director';

  return {
    totalCustomers: isDirector ? customers.length : customers.filter((c) => c.created_by === userId).length,
    totalContracts: isDirector ? contracts.length : contracts.filter((c) => c.created_by === userId).length,
    activeContracts: contracts.filter((c) => c.status === 'active').length,
    pendingContracts: contracts.filter((c) => c.status === 'pending').length,
    totalLeads: isDirector ? leads.length : leads.filter((l) => l.assigned_to === userId).length,
    openLeads: leads.filter((l) => l.status === 'new' || l.status === 'contacted').length,
    totalSchnellchecks: isDirector ? checks.length : checks.filter((s) => s.created_by === userId).length,
    totalCommissions: commissions
      .filter((c) => isDirector || c.user_id === userId)
      .reduce((sum, c) => sum + (c.amount || 0), 0),
    recentContracts: contracts.slice(-5).reverse(),
    recentLeads: leads.slice(-5).reverse(),
  };
}
