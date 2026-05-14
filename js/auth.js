// Guard: redirect to login if not authenticated
// If authenticated but no cooperative → redirect to onboarding
async function requireAuth() {
  const { data: { session } } = await _supabase.auth.getSession();
  if (!session) { window.location.href = 'index.html'; return null; }

  return session;
}

// Get current member profile (with cooperative)
async function getCurrentMember(userId) {
  const { data, error } = await _supabase
    .from('members')
    .select('*, cooperatives(*)')
    .eq('user_id', userId)
    .single();
  if (error) return null;
  return data;
}

// Logout
async function logout() {
  await _supabase.auth.signOut();
  window.location.href = 'index.html';
}

// Render sidebar avatar + name + cooperative name
function renderSidebarUser(member) {
  const el = document.getElementById('sidebar-user');
  if (!el || !member) return;
  const initials = member.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
  el.innerHTML = `
    <div class="avatar">${initials}</div>
    <div>
      <div style="font-size:12px;font-weight:600;color:var(--cream)">${member.name}</div>
      <div style="font-size:10px;color:var(--text3)">${member.share_pct}% udziałów</div>
    </div>
  `;

  // Update cooperative name in sidebar logo if present
  const logoName = document.querySelector('.logo-name');
  if (logoName && member.cooperatives?.name) {
    logoName.textContent = member.cooperatives.name;
  }
}
