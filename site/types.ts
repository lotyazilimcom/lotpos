
// Added React import to define React.ReactNode type
import React from 'react';

export interface Transaction {
  id: string;
  title: string;
  amount: number;
  date: string;
  type: 'income' | 'expense';
  status: 'completed' | 'pending' | 'cancelled';
}

export interface NavItem {
  label: string;
  icon: React.ReactNode;
  path: string;
}

export interface StatsData {
  label: string;
  value: string;
  trend: number;
  icon: React.ReactNode;
  color: string;
}