'use client';

import React, { useEffect, useState } from 'react';
import { Search, Sparkles, Image as ImageIcon, CheckCircle2, Loader2 } from 'lucide-react';

interface LoadingStepsProps {
  currentStage?: number;
}

export function LoadingSteps({ currentStage = 0 }: LoadingStepsProps) {
  const [step, setStep] = useState(0);

  useEffect(() => {
    // Progressively animate the steps for engaging user feedback
    const timer1 = setTimeout(() => setStep(1), 1200);
    const timer2 = setTimeout(() => setStep(2), 2600);
    return () => {
      clearTimeout(timer1);
      clearTimeout(timer2);
    };
  }, []);

  const effectiveStep = Math.max(step, currentStage);

  const steps = [
    {
      title: 'Analyzing Tour Link',
      desc: 'Extracting title, location, duration, and key highlights',
      icon: Search,
    },
    {
      title: 'Gemini AI Review Engine',
      desc: 'Crafting authentic 3–5 sentence first-person traveler review',
      icon: Sparkles,
    },
    {
      title: 'Sourcing Travel Photography',
      desc: 'Finding 3 high-resolution matching photos from the web',
      icon: ImageIcon,
    },
  ];

  return (
    <div className="w-full max-w-2xl mx-auto my-12 p-6 sm:p-8 rounded-2xl bg-white border border-slate-200 shadow-md backdrop-blur-xl animate-in fade-in zoom-in-95 duration-300">
      <div className="text-center mb-6">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-50 border border-indigo-200 text-indigo-700 text-xs font-semibold mb-2">
          <Loader2 className="h-3.5 w-3.5 animate-spin text-indigo-600" />
          <span>Processing Experience</span>
        </div>
        <h3 className="text-xl font-extrabold text-slate-900">Analyzing Your GetYourGuide Tour</h3>
        <p className="text-xs sm:text-sm text-slate-500 mt-1">
          Our Gemini AI pipeline is reading the tour itinerary and curating visuals
        </p>
      </div>

      <div className="space-y-4">
        {steps.map((s, idx) => {
          const Icon = s.icon;
          const isDone = effectiveStep > idx;
          const isCurrent = effectiveStep === idx;

          return (
            <div
              key={s.title}
              className={`flex items-start gap-4 p-4 rounded-xl border transition-all duration-300 ${
                isDone
                  ? 'bg-emerald-50/70 border-emerald-200 text-emerald-900'
                  : isCurrent
                  ? 'bg-indigo-50/80 border-indigo-300 text-indigo-950 shadow-xs scale-[1.01]'
                  : 'bg-slate-50/80 border-slate-200 text-slate-400 opacity-70'
              }`}
            >
              <div
                className={`mt-0.5 p-2 rounded-lg shrink-0 flex items-center justify-center transition-colors ${
                  isDone
                    ? 'bg-emerald-100 text-emerald-700'
                    : isCurrent
                    ? 'bg-indigo-600 text-white'
                    : 'bg-slate-200 text-slate-500'
                }`}
              >
                {isDone ? (
                  <CheckCircle2 className="h-5 w-5" />
                ) : isCurrent ? (
                  <Loader2 className="h-5 w-5 animate-spin" />
                ) : (
                  <Icon className="h-5 w-5" />
                )}
              </div>

              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <h4 className="text-sm font-bold text-slate-900">{s.title}</h4>
                  <span className="text-[11px] font-mono uppercase tracking-wider text-slate-500">
                    Step {idx + 1}/3
                  </span>
                </div>
                <p className="text-xs text-slate-500 mt-0.5">{s.desc}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
