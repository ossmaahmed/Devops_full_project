const API_URL = '/api';

const statusElement = document.getElementById('status');
const userList = document.getElementById('user-list');
const userForm = document.getElementById('user-form');

async function fetchUsers() {
  try {
    const res = await fetch(`${API_URL}/users`);
    if (!res.ok) throw new Error('Could not load users');
    const users = await res.json();
    userList.replaceChildren();
    if (!users.length) {
      const emptyState = document.createElement('li');
      emptyState.textContent = 'No users yet';
      userList.append(emptyState);
      return;
    }
    users.forEach((user) => {
      const item = document.createElement('li');
      item.textContent = `${user.name} - ${user.email}`;
      userList.append(item);
    });
  } catch (error) {
    userList.innerHTML = '<li>Unable to load users</li>';
  }
}

async function checkHealth() {
  try {
    const res = await fetch(`${API_URL}/health`);
    if (!res.ok) throw new Error('Backend health check failed');
    const data = await res.json();
    statusElement.textContent = data.status === 'ok' ? 'Backend is healthy ✅' : 'Backend error ❌';
  } catch (error) {
    statusElement.textContent = 'Backend unavailable ❌';
  }
}

userForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const name = document.getElementById('name').value.trim();
  const email = document.getElementById('email').value.trim();

  if (!name || !email) return;

  try {
    const response = await fetch(`${API_URL}/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email })
    });
    if (!response.ok) throw new Error('Could not add user');
    userForm.reset();
    await fetchUsers();
  } catch (error) {
    statusElement.textContent = error.message;
  }
});

checkHealth();
fetchUsers();
