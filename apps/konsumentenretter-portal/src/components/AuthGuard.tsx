'use client';
import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    const checkAuth = () => {
      const isPublicPath = pathname === '/' || pathname.startsWith('/register');
      const stored = localStorage.getItem('kr_partner');

      if (!stored) {
        if (!isPublicPath) {
          router.push('/');
        } else {
          setAuthorized(true);
        }
      } else {
        if (pathname === '/') {
          router.push('/dashboard');
        } else {
          setAuthorized(true);
        }
      }
    };

    checkAuth();
  }, [pathname, router]);

  const isPublicPath = pathname === '/' || pathname.startsWith('/register');

  // Render a loading state to prevent flash of protected content
  if (!authorized && !isPublicPath) {
    return (
      <div style={{
        display: 'flex',
        height: '100vh',
        width: '100vw',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#0A1628',
        color: '#FFFFFF',
        fontFamily: 'system-ui, sans-serif',
        flexDirection: 'column',
        gap: '12px'
      }}>
        <div style={{
          width: '24px',
          height: '24px',
          borderRadius: '50%',
          border: '3px solid rgba(255,255,255,0.2)',
          borderTopColor: '#00B4D8',
          animation: 'spin 1s linear infinite'
        }} />
        <style dangerouslySetInnerHTML={{__html: `
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
        `}} />
        <span style={{ fontSize: '0.9rem', color: '#94A3B8', fontWeight: 500 }}>Laden...</span>
      </div>
    );
  }

  return <>{children}</>;
}
