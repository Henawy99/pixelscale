'use client';

import { supabase, isSupabaseConfigured } from './supabase';

// Commission rates by role
export const ROLES = {
  sales_director: { label: 'Sales Director', rate: 100, level: 1 },
  senior_sales_manager: { label: 'Senior Sales Manager', rate: 85, level: 2 },
  sales_manager: { label: 'Sales Manager', rate: 70, level: 3 },
  kundenberater: { label: 'Kundenberater', rate: 60, level: 4 },
  tippgeber: { label: 'Tippgeber', rate: 50, level: 5 },
  partner: { label: 'Partner', rate: 0, level: 6 },
};

// Default admin user for demo/initial setup
const DEFAULT_USERS = [
  {
    id: 'admin-hashim',
    username: 'HASHIM',
    password: '123456',
    full_name: 'Hashim Soliman',
    email: 'hossamtarifo@gmail.com',
    phone: '+43 664 2378791',
    role: 'sales_director',
    commission_rate: 100,
    parent_id: null,
    is_active: true,
  },
];

// Local storage keys
const AUTH_KEY = 'tarifo_auth_user';
const USERS_KEY = 'tarifo_users';

// Initialize users in localStorage if not present
function initializeUsers() {
  if (typeof window === 'undefined') return;
  const stored = localStorage.getItem(USERS_KEY);
  if (!stored) {
    localStorage.setItem(USERS_KEY, JSON.stringify(DEFAULT_USERS));
  }
}

// Get all users
export function getUsers() {
  if (typeof window === 'undefined') return DEFAULT_USERS;
  initializeUsers();
  return JSON.parse(localStorage.getItem(USERS_KEY) || '[]');
}

// Save users
export function saveUsers(users) {
  if (typeof window === 'undefined') return;
  localStorage.setItem(USERS_KEY, JSON.stringify(users));
}

// Login
export async function login(username, password) {
  // Try Supabase first
  if (isSupabaseConfigured()) {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('username', username.toUpperCase())
        .eq('is_active', true)
        .single();

      if (data && !error) {
        // Simple password check (in production, use proper hashing)
        if (data.password_hash === password) {
          const user = { ...data };
          delete user.password_hash;
          localStorage.setItem(AUTH_KEY, JSON.stringify(user));
          return { success: true, user };
        }
      }
    } catch (e) {
      console.log('Supabase not available, using local auth');
    }
  }

  // Fallback to local storage
  const users = getUsers();
  const user = users.find(
    (u) => u.username.toUpperCase() === username.toUpperCase() && u.password === password && u.is_active
  );

  if (user) {
    const authUser = { ...user };
    delete authUser.password;
    localStorage.setItem(AUTH_KEY, JSON.stringify(authUser));
    return { success: true, user: authUser };
  }

  return { success: false, error: 'Ungültige Anmeldedaten' };
}

// Logout
export function logout() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(AUTH_KEY);
}

// Get current user
export function getCurrentUser() {
  if (typeof window === 'undefined') return null;
  const stored = localStorage.getItem(AUTH_KEY);
  if (!stored) return null;
  try {
    return JSON.parse(stored);
  } catch {
    return null;
  }
}

// Check if user is authenticated
export function isAuthenticated() {
  return getCurrentUser() !== null;
}

// Add new user
export function addUser(userData) {
  const users = getUsers();
  const newUser = {
    id: `user-${Date.now()}`,
    ...userData,
    commission_rate: ROLES[userData.role]?.rate || 0,
    is_active: true,
    created_at: new Date().toISOString(),
  };
  users.push(newUser);
  saveUsers(users);
  return newUser;
}

// Update user
export function updateUser(userId, updates) {
  const users = getUsers();
  const idx = users.findIndex((u) => u.id === userId);
  if (idx !== -1) {
    users[idx] = { ...users[idx], ...updates };
    if (updates.role) {
      users[idx].commission_rate = ROLES[updates.role]?.rate || 0;
    }
    saveUsers(users);
    return users[idx];
  }
  return null;
}

// Get user hierarchy (subordinates)
export function getSubordinates(userId) {
  const users = getUsers();
  const result = [];
  const queue = [userId];
  while (queue.length > 0) {
    const currentId = queue.shift();
    const subs = users.filter((u) => u.parent_id === currentId && u.is_active);
    result.push(...subs);
    subs.forEach((s) => queue.push(s.id));
  }
  return result;
}

// Get management chain (upline)
export function getManagementChain(userId) {
  const users = getUsers();
  const chain = [];
  let currentId = userId;
  while (currentId) {
    const user = users.find((u) => u.id === currentId);
    if (!user || !user.parent_id) break;
    const manager = users.find((u) => u.id === user.parent_id);
    if (manager) {
      chain.push(manager);
      currentId = manager.id;
    } else {
      break;
    }
  }
  return chain;
}

// Calculate commissions for a contract
export function calculateCommissions(contractCreatorId, totalProvision) {
  const users = getUsers();
  const creator = users.find((u) => u.id === contractCreatorId);
  if (!creator) return [];

  const commissions = [];
  const creatorRate = ROLES[creator.role]?.rate || 0;

  // Direct commission for the creator
  commissions.push({
    user_id: creator.id,
    user_name: creator.full_name,
    role: creator.role,
    rate: creatorRate,
    amount: (totalProvision * creatorRate) / 100,
    type: 'direct',
  });

  // Leadership bonuses up the chain
  let lastRate = creatorRate;
  const chain = getManagementChain(contractCreatorId);

  for (const manager of chain) {
    const managerRate = ROLES[manager.role]?.rate || 0;
    if (managerRate > lastRate) {
      const diff = managerRate - lastRate;
      commissions.push({
        user_id: manager.id,
        user_name: manager.full_name,
        role: manager.role,
        rate: diff,
        amount: (totalProvision * diff) / 100,
        type: 'leadership_bonus',
      });
      lastRate = managerRate;
    }
  }

  return commissions;
}
