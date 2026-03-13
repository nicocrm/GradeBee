import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router';
import './globals.css';

import { AuthProvider } from '@/lib/auth';
import RequireAuth from '@/components/RequireAuth';
import PageLayout from '@/components/PageLayout';
import Login from '@/pages/Login';
import ClassList from '@/pages/ClassList';
import ClassDetails from '@/pages/ClassDetails';
import StudentDetails from '@/pages/StudentDetails';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<RequireAuth><PageLayout /></RequireAuth>}>
            <Route index element={<Navigate to="/classes" replace />} />
            <Route path="/classes" element={<ClassList />} />
            <Route path="/classes/:classId" element={<ClassDetails />} />
            <Route path="/classes/:classId/students/:studentId" element={<StudentDetails />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);
