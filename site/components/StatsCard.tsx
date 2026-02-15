
import React from 'react';
import { TrendingUp, TrendingDown } from 'lucide-react';

interface StatsCardProps {
  label: string;
  value: string;
  trend: number;
  icon: React.ReactNode;
  color: string;
}

const StatsCard: React.FC<StatsCardProps> = ({ label, value, trend, icon, color }) => {
  const isPositive = trend >= 0;

  return (
    <div className="bg-paper-light dark:bg-paper-dark rounded-xl p-5 shadow-sm border border-gray-100 dark:border-gray-800 transition-all hover:shadow-md">
      <div className="flex items-center justify-between mb-3">
        <div className={`p-2.5 rounded-lg ${color} bg-opacity-10 text-${color.split('-')[1]}`}>
          {icon}
        </div>
        <div className={`flex items-center text-xs font-medium ${isPositive ? 'text-green-500' : 'text-red-500'}`}>
          {isPositive ? <TrendingUp size={14} className="mr-1" /> : <TrendingDown size={14} className="mr-1" />}
          {Math.abs(trend)}%
        </div>
      </div>
      <div>
        <h3 className="text-muted text-xs font-medium tracking-wider mb-1">{label}</h3>
        <p className="text-2xl font-bold text-primary dark:text-white">{value}</p>
      </div>
    </div>
  );
};

export default StatsCard;
