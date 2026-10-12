// Class Attendance Web Client Application - Milestone 3

const API_BASE = '/api/v1';

let currentUser = null;
let currentActiveSession = null;
let lastRecognitionOutput = null;
let webcamStream = null;

// Initialize App
document.addEventListener('DOMContentLoaded', () => {
    checkSession();
    setupEventListeners();
});

function fillDemo(username, password) {
    document.getElementById('username_or_email').value = username;
    document.getElementById('password').value = password;
}

function showToast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<i class="fa-solid ${type === 'success' ? 'fa-circle-check' : 'fa-circle-exclamation'}"></i> <span>${message}</span>`;
    container.appendChild(toast);
    setTimeout(() => { toast.remove(); }, 4000);
}

// Session Check on Load
async function checkSession() {
    try {
        const res = await fetch(`${API_BASE}/auth/me`, { headers: getAuthHeaders() });
        if (res.ok) {
            currentUser = await res.json();
            showAppLayout();
        } else {
            showLoginLayout();
        }
    } catch (err) {
        showLoginLayout();
    }
}

function getAuthHeaders() {
    const token = localStorage.getItem('access_token');
    const headers = { 'Content-Type': 'application/json' };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
}

function showLoginLayout() {
    document.getElementById('login-view').classList.remove('hidden');
    document.getElementById('app-view').classList.add('hidden');
}

function showAppLayout() {
    document.getElementById('login-view').classList.add('hidden');
    document.getElementById('app-view').classList.remove('hidden');

    document.getElementById('user-display-name').textContent = currentUser.full_name || currentUser.username;
    document.getElementById('user-display-email').textContent = currentUser.email;

    const roleBadge = document.getElementById('role-badge');
    roleBadge.textContent = currentUser.role;

    if (currentUser.role === 'ADMIN') {
        roleBadge.className = 'badge bg-purple';
        document.getElementById('admin-nav').classList.remove('hidden');
        document.getElementById('faculty-nav').classList.add('hidden');
        switchTab('admin-dashboard');
        loadAdminDashboardMetrics();
    } else {
        roleBadge.className = 'badge bg-blue';
        document.getElementById('admin-nav').classList.add('hidden');
        document.getElementById('faculty-nav').classList.remove('hidden');
        switchTab('faculty-dashboard');
        loadFacultyDashboard();
    }
}

function setupEventListeners() {
    // Login Form Submit
    document.getElementById('login-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const username_or_email = document.getElementById('username_or_email').value;
        const password = document.getElementById('password').value;
        const errorBanner = document.getElementById('login-error');

        errorBanner.classList.add('hidden');

        try {
            const res = await fetch(`${API_BASE}/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username_or_email, password })
            });

            const data = await res.json();
            if (res.ok) {
                localStorage.setItem('access_token', data.access_token);
                await checkSession();
                showToast('Successfully signed in!', 'success');
            } else {
                errorBanner.textContent = data.detail || 'Login failed';
                errorBanner.classList.remove('hidden');
            }
        } catch (err) {
            errorBanner.textContent = 'Server connection error';
            errorBanner.classList.remove('hidden');
        }
    });

    // Logout Button
    document.getElementById('logout-btn').addEventListener('click', async () => {
        try {
            await fetch(`${API_BASE}/auth/logout`, { method: 'POST', headers: getAuthHeaders() });
        } catch (err) {}
        localStorage.removeItem('access_token');
        currentUser = null;
        showLoginLayout();
        showToast('Logged out successfully');
    });

    // Tab Navigation Handler
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const tabId = item.getAttribute('data-tab');
            switchTab(tabId);
        });
    });

    // Forms inside Modals
    setupModalForm('form-add-faculty', '/admin/faculty', () => loadFacultyList());
    setupModalForm('form-add-student', '/admin/students', () => loadStudentList());
    setupModalForm('form-add-class', '/admin/classes', () => { loadClassList(); populateDropdowns(); });
    setupModalForm('form-add-subject', '/admin/subjects', () => { loadSubjectList(); populateDropdowns(); });
    setupModalForm('form-add-period', '/admin/periods', () => { loadPeriodList(); populateDropdowns(); });
    setupModalForm('form-add-assignment', '/admin/assignments', () => { loadAssignmentList(); populateDropdowns(); });
    setupModalForm('form-add-timetable', '/admin/timetable', () => loadTimetableList());

    setupAdminCorrectionForm();
    setupStudentEnrollmentForm();
}

function setupModalForm(formId, endpoint, onSuccess) {
    const form = document.getElementById(formId);
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(form);
        const body = {};
        formData.forEach((value, key) => {
            if (['period_number', 'faculty_id', 'subject_id', 'class_id', 'period_id', 'assignment_id', 'student_id'].includes(key)) {
                body[key] = parseInt(value);
            } else {
                body[key] = value;
            }
        });

        try {
            const res = await fetch(`${API_BASE}${endpoint}`, {
                method: 'POST',
                headers: getAuthHeaders(),
                body: JSON.stringify(body)
            });
            const data = await res.json();
            if (res.ok) {
                showToast('Action saved successfully', 'success');
                form.reset();
                const modal = form.closest('.modal');
                if (modal) modal.classList.remove('active');
                if (onSuccess) onSuccess();
            } else {
                showToast(data.detail || 'Error saving item', 'error');
            }
        } catch (err) {
            showToast('Network error', 'error');
        }
    });
}

function setupAdminCorrectionForm() {
    const form = document.getElementById('form-admin-correct');
    if (!form) return;
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const sessionId = document.getElementById('correct-session-id').value;
        const studentId = parseInt(document.getElementById('correct-select-student').value);
        const newStatus = form.elements['new_status'].value;
        const reason = form.elements['reason'].value;

        try {
            const res = await fetch(`${API_BASE}/admin/sessions/${sessionId}/correction`, {
                method: 'POST',
                headers: getAuthHeaders(),
                body: JSON.stringify({ student_id: studentId, new_status: newStatus, reason: reason })
            });
            const data = await res.json();
            if (res.ok) {
                showToast('Correction applied and logged', 'success');
                form.reset();
                closeModal('modal-admin-correct');
                loadAdminSessionsList();
            } else {
                showToast(data.detail || 'Error applying correction', 'error');
            }
        } catch (err) {
            showToast('Network error', 'error');
        }
    });
}

function setupStudentEnrollmentForm() {
    const form = document.getElementById('form-enroll-student');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const studentId = document.getElementById('enroll-student-id').value;
        const fileInput = document.getElementById('enroll-image-file');

        if (!fileInput.files || fileInput.files.length === 0) {
            showToast('Select an image file first', 'error');
            return;
        }

        const formData = new FormData();
        formData.append('file', fileInput.files[0]);

        try {
            const token = localStorage.getItem('access_token');
            const res = await fetch(`${API_BASE}/admin/students/${studentId}/enroll-face`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` },
                body: formData
            });

            const data = await res.json();
            if (res.ok) {
                showToast(`Face enrolled for ${data.full_name}`, 'success');
                form.reset();
                closeModal('modal-enroll-student');
                loadStudentList();
            } else {
                showToast(data.detail || 'Enrollment error', 'error');
            }
        } catch (err) {
            showToast('Network error during face enrollment', 'error');
        }
    });
}

// Switch Active Tab
function switchTab(tabId) {
    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(el => el.classList.remove('active'));

    const activeNav = document.querySelector(`.nav-item[data-tab="${tabId}"]`);
    if (activeNav) activeNav.classList.add('active');

    const pane = document.getElementById(`tab-${tabId}`);
    if (pane) pane.classList.add('active');

    const titles = {
        'admin-dashboard': 'Admin Overview',
        'admin-faculty': 'Faculty Directory',
        'admin-students': 'Student Roster & Biometric Enrollment',
        'admin-classes': 'Class Sections',
        'admin-subjects': 'Subject Catalogue',
        'admin-periods': 'Period Timings',
        'admin-assignments': 'Faculty Assignments',
        'admin-timetable': 'Master Timetable',
        'admin-sessions': 'Class Sessions Monitor',
        'admin-audit': 'Audit History Log',
        'faculty-dashboard': 'Faculty Mobile Portal',
        'faculty-timetable': 'My Personalized Timetable'
    };
    document.getElementById('page-title').textContent = titles[tabId] || 'Dashboard';

    if (tabId === 'admin-faculty') loadFacultyList();
    if (tabId === 'admin-students') { loadStudentList(); populateDropdowns(); }
    if (tabId === 'admin-classes') loadClassList();
    if (tabId === 'admin-subjects') loadSubjectList();
    if (tabId === 'admin-periods') loadPeriodList();
    if (tabId === 'admin-assignments') { loadAssignmentList(); populateDropdowns(); }
    if (tabId === 'admin-timetable') { loadTimetableList(); populateDropdowns(); }
    if (tabId === 'admin-sessions') loadAdminSessionsList();
    if (tabId === 'admin-audit') loadAdminAuditLogs();
    if (tabId === 'faculty-dashboard') loadFacultyDashboard();
    if (tabId === 'faculty-timetable') loadFacultyTimetable();
}

function openModal(id) {
    populateDropdowns();
    document.getElementById(id).classList.add('active');
}

function closeModal(id) {
    document.getElementById(id).classList.remove('active');
}

// ==========================================
// ADMIN LOADERS & CRUD
// ==========================================

async function loadAdminDashboardMetrics() {
    try {
        const [f, st, cl, sb] = await Promise.all([
            fetch(`${API_BASE}/admin/faculty`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/students`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/classes`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/subjects`, { headers: getAuthHeaders() }).then(r => r.json())
        ]);
        document.getElementById('stat-faculty-count').textContent = Array.isArray(f) ? f.length : 0;
        document.getElementById('stat-student-count').textContent = Array.isArray(st) ? st.length : 0;
        document.getElementById('stat-class-count').textContent = Array.isArray(cl) ? cl.length : 0;
        document.getElementById('stat-subject-count').textContent = Array.isArray(sb) ? sb.length : 0;
    } catch (e) {}
}

async function loadFacultyList() {
    const tbody = document.getElementById('table-faculty-body');
    try {
        const res = await fetch(`${API_BASE}/admin/faculty`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.employee_id}</strong></td>
                <td>${item.full_name}</td>
                <td>${item.username}</td>
                <td>${item.email}</td>
                <td>${item.department || '-'}</td>
                <td><span class="tag ${item.is_active ? 'tag-success' : 'tag-danger'}">${item.is_active ? 'Active' : 'Disabled'}</span></td>
                <td><button class="btn btn-secondary btn-sm" onclick="deleteFaculty(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deleteFaculty(id) {
    if (!confirm('Delete faculty member?')) return;
    const res = await fetch(`${API_BASE}/admin/faculty/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Faculty deleted'); loadFacultyList(); }
}

async function loadStudentList() {
    const tbody = document.getElementById('table-students-body');
    try {
        const res = await fetch(`${API_BASE}/admin/students`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.roll_number}</strong></td>
                <td>${item.full_name}</td>
                <td>${item.email || '-'}</td>
                <td>${item.class_name ? `<span class="tag tag-info">${item.class_name}</span>` : '<span class="text-muted">Unassigned</span>'}</td>
                <td><span class="tag tag-success"><i class="fa-solid fa-face-smile"></i> Enrolled</span></td>
                <td><span class="tag ${item.is_active ? 'tag-success' : 'tag-danger'}">${item.is_active ? 'Active' : 'Inactive'}</span></td>
                <td>
                    <button class="btn btn-primary btn-sm" onclick="openEnrollModal(${item.id}, '${item.full_name}')"><i class="fa-solid fa-id-card"></i> Enroll Face</button>
                    <button class="btn btn-secondary btn-sm" onclick="deleteStudent(${item.id})"><i class="fa-solid fa-trash"></i></button>
                </td>
            </tr>
        `).join('');
    } catch (e) {}
}

function openEnrollModal(studentId, fullName) {
    document.getElementById('enroll-student-id').value = studentId;
    document.getElementById('enroll-student-name').value = fullName;
    openModal('modal-enroll-student');
}

async function deleteStudent(id) {
    if (!confirm('Delete student?')) return;
    const res = await fetch(`${API_BASE}/admin/students/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Student deleted'); loadStudentList(); }
}

async function loadClassList() {
    const tbody = document.getElementById('table-classes-body');
    try {
        const res = await fetch(`${API_BASE}/admin/classes`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.name}</strong></td>
                <td>${item.grade_level || '-'}</td>
                <td>${item.academic_year || '-'}</td>
                <td><button class="btn btn-secondary btn-sm" onclick="deleteClass(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deleteClass(id) {
    if (!confirm('Delete class?')) return;
    const res = await fetch(`${API_BASE}/admin/classes/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Class deleted'); loadClassList(); }
}

async function loadSubjectList() {
    const tbody = document.getElementById('table-subjects-body');
    try {
        const res = await fetch(`${API_BASE}/admin/subjects`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.code}</strong></td>
                <td>${item.name}</td>
                <td>${item.description || '-'}</td>
                <td><button class="btn btn-secondary btn-sm" onclick="deleteSubject(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deleteSubject(id) {
    if (!confirm('Delete subject?')) return;
    const res = await fetch(`${API_BASE}/admin/subjects/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Subject deleted'); loadSubjectList(); }
}

async function loadPeriodList() {
    const tbody = document.getElementById('table-periods-body');
    try {
        const res = await fetch(`${API_BASE}/admin/periods`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>Period ${item.period_number}</strong></td>
                <td>${item.name}</td>
                <td><span class="time-pill">${item.start_time}</span></td>
                <td><span class="time-pill">${item.end_time}</span></td>
                <td><button class="btn btn-secondary btn-sm" onclick="deletePeriod(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deletePeriod(id) {
    if (!confirm('Delete period?')) return;
    const res = await fetch(`${API_BASE}/admin/periods/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Period deleted'); loadPeriodList(); }
}

function formatFacultyDisplay(item) {
    if (!item.faculty_name || item.faculty_name === 'Faculty assignment pending') {
        return '<span class="tag tag-warning"><i class="fa-solid fa-clock"></i> Pending Assignment</span>';
    }
    if (item.authorized_faculty_names && item.authorized_faculty_names.length > 1) {
        return `<div><span class="tag tag-success" style="font-size:0.75rem; margin-bottom:4px; display:inline-block;"><i class="fa-solid fa-users"></i> Authorized Faculty (${item.authorized_faculty_names.length})</span><div class="font-weight-bold">${item.authorized_faculty_names.join(', ')}</div></div>`;
    }
    return `<strong>${item.faculty_name}</strong>`;
}

async function loadAssignmentList() {
    const tbody = document.getElementById('table-assignments-body');
    try {
        const res = await fetch(`${API_BASE}/admin/assignments`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td>${formatFacultyDisplay(item)}</td>
                <td><span class="tag tag-info">${item.subject_code}</span></td>
                <td>${item.subject_name}</td>
                <td>${item.class_name}</td>
                <td><button class="btn btn-secondary btn-sm" onclick="deleteAssignment(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deleteAssignment(id) {
    if (!confirm('Delete assignment?')) return;
    const res = await fetch(`${API_BASE}/admin/assignments/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Assignment deleted'); loadAssignmentList(); }
}

async function loadTimetableList() {
    const tbody = document.getElementById('table-timetable-body');
    try {
        const res = await fetch(`${API_BASE}/admin/timetable`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.day_of_week}</strong></td>
                <td>${item.period_name}</td>
                <td><span class="time-pill">${item.start_time} - ${item.end_time}</span></td>
                <td>${formatFacultyDisplay(item)}</td>
                <td><span class="tag tag-info">${item.subject_code}</span> ${item.subject_name}</td>
                <td>${item.class_name}</td>
                <td><button class="btn btn-secondary btn-sm" onclick="deleteTimetableEntry(${item.id})"><i class="fa-solid fa-trash"></i></button></td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function deleteTimetableEntry(id) {
    if (!confirm('Delete timetable entry?')) return;
    const res = await fetch(`${API_BASE}/admin/timetable/${id}`, { method: 'DELETE', headers: getAuthHeaders() });
    if (res.ok) { showToast('Timetable entry deleted'); loadTimetableList(); }
}

async function loadAdminSessionsList() {
    const tbody = document.getElementById('table-admin-sessions-body');
    try {
        const res = await fetch(`${API_BASE}/admin/sessions`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>#${item.session_id}</strong></td>
                <td>${item.date}</td>
                <td>${item.faculty_name}</td>
                <td><span class="tag tag-info">${item.subject_code}</span> ${item.subject_name}</td>
                <td>${item.class_name}</td>
                <td><span class="tag ${item.status === 'ACTIVE' ? 'tag-success' : 'tag-info'}">${item.status}</span></td>
                <td>
                    <button class="btn btn-secondary btn-sm" onclick="openAdminCorrectionModal(${item.session_id})">
                        <i class="fa-solid fa-pen-to-square"></i> Correct
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function openAdminCorrectionModal(sessionId) {
    document.getElementById('correct-session-id').value = sessionId;
    try {
        const res = await fetch(`${API_BASE}/admin/sessions/${sessionId}`, { headers: getAuthHeaders() });
        const details = await res.json();
        const selectStudent = document.getElementById('correct-select-student');
        selectStudent.innerHTML = details.roster.map(st => `
            <option value="${st.student_id}">${st.roll_number} - ${st.full_name} (Current: ${st.attendance_status})</option>
        `).join('');
        openModal('modal-admin-correct');
    } catch (e) { showToast('Error loading session roster', 'error'); }
}

async function loadAdminAuditLogs() {
    const tbody = document.getElementById('table-admin-audit-body');
    try {
        const res = await fetch(`${API_BASE}/admin/audit-logs`, { headers: getAuthHeaders() });
        const list = await res.json();
        tbody.innerHTML = list.map(item => `
            <tr>
                <td><small>${item.timestamp || '-'}</small></td>
                <td><strong>${item.username}</strong></td>
                <td><span class="tag tag-warning">${item.action}</span></td>
                <td>${item.details}</td>
            </tr>
        `).join('');
    } catch (e) {}
}

async function populateDropdowns() {
    try {
        const [faculties, subjects, classes, periods, assignments] = await Promise.all([
            fetch(`${API_BASE}/admin/faculty`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/subjects`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/classes`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/periods`, { headers: getAuthHeaders() }).then(r => r.json()),
            fetch(`${API_BASE}/admin/assignments`, { headers: getAuthHeaders() }).then(r => r.json())
        ]);

        const studentClass = document.getElementById('select-student-class');
        if (studentClass) studentClass.innerHTML = classes.map(c => `<option value="${c.id}">${c.name}</option>`).join('');

        const assignFaculty = document.getElementById('select-assign-faculty');
        if (assignFaculty) assignFaculty.innerHTML = faculties.map(f => `<option value="${f.id}">${f.full_name} (${f.employee_id})</option>`).join('');

        const assignSubj = document.getElementById('select-assign-subject');
        if (assignSubj) assignSubj.innerHTML = subjects.map(s => `<option value="${s.id}">${s.code} - ${s.name}</option>`).join('');

        const assignClass = document.getElementById('select-assign-class');
        if (assignClass) assignClass.innerHTML = classes.map(c => `<option value="${c.id}">${c.name}</option>`).join('');

        const ttPeriod = document.getElementById('select-timetable-period');
        if (ttPeriod) ttPeriod.innerHTML = periods.map(p => `<option value="${p.id}">${p.name} (${p.start_time} - ${p.end_time})</option>`).join('');

        const ttAssign = document.getElementById('select-timetable-assignment');
        if (ttAssign) ttAssign.innerHTML = assignments.map(a => `<option value="${a.id}">${a.faculty_name} | ${a.subject_code} | ${a.class_name}</option>`).join('');
    } catch (e) {}
}

// ==========================================
// FACULTY DASHBOARD & RECOGNITION WORKFLOW
// ==========================================

async function loadFacultyDashboard() {
    const mobileScreen = document.getElementById('mobile-session-screen');
    const timeDisplay = document.getElementById('mobile-server-time');

    try {
        const sessionRes = await fetch(`${API_BASE}/faculty/sessions/active`, { headers: getAuthHeaders() });
        const sessionData = await sessionRes.json();

        if (sessionData.has_active_session && sessionData.session) {
            renderActiveSessionScreen(sessionData.session);
            return;
        }

        const classRes = await fetch(`${API_BASE}/faculty/active-class`, { headers: getAuthHeaders() });
        const classData = await classRes.json();

        timeDisplay.textContent = `Server: ${classData.current_date} ${classData.current_time} (${classData.current_day})`;

        if (classData.has_active_class && classData.active_class) {
            const ac = classData.active_class;
            mobileScreen.innerHTML = `
                <div class="mobile-class-card">
                    <div class="mobile-subject"><i class="fa-solid fa-book-open"></i> ${ac.subject_code} - ${ac.subject_name}</div>
                    <div class="mobile-class-name"><i class="fa-solid fa-users"></i> ${ac.class_name}</div>
                    <div class="mobile-time-range"><i class="fa-regular fa-clock"></i> ${ac.period_name}: ${ac.start_time} – ${ac.end_time}</div>
                    <button class="btn btn-primary btn-block touch-btn mt-4" onclick="startFacultySession()">
                        <i class="fa-solid fa-play"></i> START ATTENDANCE
                    </button>
                </div>
            `;
        } else {
            mobileScreen.innerHTML = `
                <div class="card p-4 text-center">
                    <h3 style="color: var(--text-muted); font-size: 1.2rem;"><i class="fa-solid fa-bed"></i> No active class</h3>
                    <p class="text-muted mt-2">There is no class scheduled for period slot ${classData.current_time} on ${classData.current_day}.</p>
                </div>
            `;
        }
    } catch (err) {
        mobileScreen.innerHTML = '<p class="text-danger text-center">Error fetching class schedule.</p>';
    }
}

async function startFacultySession() {
    try {
        const res = await fetch(`${API_BASE}/faculty/sessions/start`, { method: 'POST', headers: getAuthHeaders() });
        const data = await res.json();
        if (res.ok) {
            showToast('Attendance session started!', 'success');
            loadFacultyDashboard();
        } else {
            showToast(data.detail || 'Error starting session', 'error');
        }
    } catch (e) { showToast('Network error', 'error'); }
}

function renderActiveSessionScreen(session) {
    const mobileScreen = document.getElementById('mobile-session-screen');
    currentActiveSession = session;

    const s = session.summary;
    mobileScreen.innerHTML = `
        <div class="session-active-card">
            <div class="session-header">
                <div>
                    <h3 style="font-size: 1.2rem; color: var(--success);"><i class="fa-solid fa-circle-play"></i> ATTENDANCE ACTIVE</h3>
                    <div style="font-size: 0.9rem; color: var(--text-muted);">${session.subject_code} - ${session.class_name}</div>
                </div>
                <div class="time-pill">${session.start_time} - ${session.end_time}</div>
            </div>

            <!-- Photo Action Buttons for Mobile Camera & Group Upload -->
            <div class="photo-actions-grid mt-3">
                <button class="btn btn-primary touch-btn" onclick="document.getElementById('input-group-camera').click()">
                    <i class="fa-solid fa-camera"></i> TAKE GROUP PHOTO
                </button>
                <button class="btn btn-secondary touch-btn" onclick="document.getElementById('input-group-gallery').click()">
                    <i class="fa-solid fa-images"></i> FROM GALLERY
                </button>
            </div>
            <button class="btn btn-secondary btn-block touch-btn mb-3" onclick="openWebcamModal()">
                <i class="fa-solid fa-video"></i> LIVE WEBCAM CAPTURE
            </button>

            <!-- Counters Grid -->
            <div class="counters-grid">
                <div class="counter-box">
                    <div class="num text-success">${s.present_count}</div>
                    <div class="lbl">Present</div>
                </div>
                <div class="counter-box">
                    <div class="num text-danger">${s.absent_count}</div>
                    <div class="lbl">Absent</div>
                </div>
                <div class="counter-box">
                    <div class="num text-muted">${s.remaining_count}</div>
                    <div class="lbl">Remaining</div>
                </div>
                <div class="counter-box">
                    <div class="num" style="color: var(--primary);">${s.total_students}</div>
                    <div class="lbl">Total</div>
                </div>
            </div>

            <!-- Student Roster Touch List -->
            <div class="roster-list">
                ${session.roster.map(st => `
                    <div class="roster-item">
                        <div class="roster-info">
                            <div class="roll">${st.roll_number}</div>
                            <div class="name">${st.full_name}</div>
                        </div>
                        <div class="roster-actions">
                            <button class="btn-touch-att ${st.attendance_status === 'PRESENT' ? 'active-present' : ''}"
                                onclick="markStudentAttendance(${session.session_id}, ${st.student_id}, 'PRESENT')">
                                <i class="fa-solid fa-check"></i> Present
                            </button>
                            <button class="btn-touch-att ${st.attendance_status === 'ABSENT' ? 'active-absent' : ''}"
                                onclick="markStudentAttendance(${session.session_id}, ${st.student_id}, 'ABSENT')">
                                <i class="fa-solid fa-xmark"></i> Absent
                            </button>
                        </div>
                    </div>
                `).join('')}
            </div>

            <!-- Complete Session Button -->
            <button class="btn btn-danger btn-block touch-btn mt-3" onclick="completeFacultySession(${session.session_id})">
                <i class="fa-solid fa-flag-checkered"></i> COMPLETE ATTENDANCE
            </button>
        </div>
    `;
}

// Group Photo Upload Handler
async function handleGroupPhotoUpload(fileInput) {
    if (!fileInput.files || fileInput.files.length === 0) return;
    if (!currentActiveSession) return;

    const file = fileInput.files[0];
    const formData = new FormData();
    formData.append('file', file);

    showToast('Processing photo with multi-face recognition engine...', 'info');

    try {
        const token = localStorage.getItem('access_token');
        const res = await fetch(`${API_BASE}/faculty/sessions/${currentActiveSession.session_id}/recognize-image`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` },
            body: formData
        });

        const data = await res.json();
        if (res.ok) {
            lastRecognitionOutput = data;
            renderRecognitionReviewScreen(data);
        } else {
            showToast(data.detail || 'Photo recognition error', 'error');
        }
    } catch (e) {
        showToast('Network error during recognition', 'error');
    }
    fileInput.value = '';
}

// WebRTC Live Webcam Functions
function openWebcamModal() {
    openModal('modal-live-camera');
    const video = document.getElementById('webcam-video');

    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } })
            .then(stream => {
                webcamStream = stream;
                video.srcObject = stream;
            })
            .catch(err => {
                showToast('Unable to access device camera', 'error');
            });
    }
}

function closeWebcamModal() {
    if (webcamStream) {
        webcamStream.getTracks().forEach(track => track.stop());
        webcamStream = null;
    }
    closeModal('modal-live-camera');
}

async function captureAndRecognizeWebcam() {
    const video = document.getElementById('webcam-video');
    const canvas = document.getElementById('webcam-canvas');
    if (!video || !webcamStream) return;

    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    canvas.toBlob(async (blob) => {
        closeWebcamModal();
        if (!blob) return;

        const formData = new FormData();
        formData.append('file', blob, 'webcam_frame.jpg');

        showToast('Processing captured camera frame...', 'info');

        try {
            const token = localStorage.getItem('access_token');
            const res = await fetch(`${API_BASE}/faculty/sessions/${currentActiveSession.session_id}/recognize-image`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` },
                body: formData
            });
            const data = await res.json();
            if (res.ok) {
                lastRecognitionOutput = data;
                renderRecognitionReviewScreen(data);
            } else {
                showToast(data.detail || 'Webcam frame recognition error', 'error');
            }
        } catch (e) { showToast('Network error', 'error'); }
    }, 'image/jpeg', 0.9);
}

// Render Recognition Results Breakdown & Review Screen
function renderRecognitionReviewScreen(data) {
    const mobileScreen = document.getElementById('mobile-session-screen');

    const highConf = data.results.filter(r => r.status === 'HIGH_CONFIDENCE');
    const uncertain = data.results.filter(r => r.status === 'UNCERTAIN');
    const unknown = data.results.filter(r => r.status === 'UNKNOWN');

    mobileScreen.innerHTML = `
        <div class="card p-4">
            <h3 style="font-size: 1.2rem; color: var(--primary);"><i class="fa-solid fa-microscope"></i> Recognition Breakdown</h3>

            <div class="counters-grid mt-3">
                <div class="counter-box">
                    <div class="num">${data.faces_detected}</div>
                    <div class="lbl">Faces Detected</div>
                </div>
                <div class="counter-box">
                    <div class="num text-success">${data.high_confidence_matches}</div>
                    <div class="lbl">High Confidence</div>
                </div>
                <div class="counter-box">
                    <div class="num text-warning">${data.uncertain_matches}</div>
                    <div class="lbl">Uncertain Review</div>
                </div>
                <div class="counter-box">
                    <div class="num text-danger">${data.unknown_faces}</div>
                    <div class="lbl">Unknown</div>
                </div>
            </div>

            <!-- High Confidence Candidates -->
            <div class="mt-3">
                <h4 style="font-size: 0.95rem; color: var(--success);"><i class="fa-solid fa-circle-check"></i> Proposed Present (High Confidence)</h4>
                ${highConf.length === 0 ? '<p class="text-muted small">None</p>' : `
                    <div class="roster-list mt-2">
                        ${highConf.map(hc => `
                            <div class="roster-item">
                                <div>
                                    <strong>${hc.roll_number} - ${hc.name}</strong>
                                    <div class="text-muted small">Match Score: ${hc.derived_score}% (Distance: ${hc.distance})</div>
                                </div>
                                <span class="tag tag-success">High Confidence</span>
                            </div>
                        `).join('')}
                    </div>
                `}
            </div>

            <!-- Uncertain Match Review Queue -->
            <div class="mt-4">
                <h4 style="font-size: 0.95rem; color: var(--warning);"><i class="fa-solid fa-circle-question"></i> Review Uncertain Matches</h4>
                ${uncertain.length === 0 ? '<p class="text-muted small">No uncertain matches require manual review.</p>' : `
                    <div class="mt-2">
                        ${uncertain.map(uc => `
                            <div class="review-card">
                                <div><strong>Face #${uc.face_index}</strong> (Closest distance: ${uc.distance || 'N/A'})</div>
                                <label class="small text-muted mt-1">Select candidate match:</label>
                                <select id="review-select-${uc.face_index}">
                                    <option value="">-- Mark as Unknown / Ignore --</option>
                                    ${uc.candidates.map(cand => `
                                        <option value="${cand.student_id}" ${cand.student_id === uc.student_id ? 'selected' : ''}>
                                            ${cand.roll_number} - ${cand.name} (Score: ${cand.derived_score}%)
                                        </option>
                                    `).join('')}
                                </select>
                            </div>
                        `).join('')}
                    </div>
                `}
            </div>

            <!-- Action Buttons -->
            <div class="mt-4" style="display: flex; gap: 0.5rem;">
                <button class="btn btn-primary btn-block touch-btn" onclick="submitConfirmedBiometricAttendance()">
                    <i class="fa-solid fa-check-double"></i> CONFIRM ATTENDANCE
                </button>
                <button class="btn btn-secondary touch-btn" onclick="loadFacultyDashboard()">
                    Cancel
                </button>
            </div>
        </div>
    `;
}

async function submitConfirmedBiometricAttendance() {
    if (!lastRecognitionOutput || !currentActiveSession) return;

    const confirmedList = [];

    // 1. Include all High Confidence candidates
    const highConf = lastRecognitionOutput.results.filter(r => r.status === 'HIGH_CONFIDENCE');
    highConf.forEach(hc => {
        if (hc.student_id) {
            confirmedList.push({
                student_id: hc.student_id,
                status: 'PRESENT',
                recognized_via: 'GROUP_PHOTO'
            });
        }
    });

    // 2. Include faculty choices for Uncertain matches
    const uncertain = lastRecognitionOutput.results.filter(r => r.status === 'UNCERTAIN');
    uncertain.forEach(uc => {
        const select = document.getElementById(`review-select-${uc.face_index}`);
        if (select && select.value) {
            confirmedList.push({
                student_id: parseInt(select.value),
                status: 'PRESENT',
                recognized_via: 'GROUP_PHOTO'
            });
        }
    });

    if (confirmedList.length === 0) {
        showToast('No students selected to confirm', 'warning');
        loadFacultyDashboard();
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/faculty/sessions/${currentActiveSession.session_id}/confirm-recognition`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify({ confirmed_candidates: confirmedList })
        });

        const data = await res.json();
        if (res.ok) {
            showToast(data.message, 'success');
            loadFacultyDashboard();
        } else {
            showToast(data.detail || 'Confirmation error', 'error');
        }
    } catch (e) {
        showToast('Network error during confirmation', 'error');
    }
}

async function markStudentAttendance(sessionId, studentId, statusVal) {
    try {
        const res = await fetch(`${API_BASE}/faculty/sessions/${sessionId}/attendance`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify({ student_id: studentId, status: statusVal })
        });
        if (res.ok) {
            const detailsRes = await fetch(`${API_BASE}/faculty/sessions/${sessionId}`, { headers: getAuthHeaders() });
            const sessionDetails = await detailsRes.json();
            renderActiveSessionScreen(sessionDetails);
        } else {
            const data = await res.json();
            showToast(data.detail || 'Error marking attendance', 'error');
        }
    } catch (e) { showToast('Network error', 'error'); }
}

async function completeFacultySession(sessionId) {
    if (!confirm('Complete attendance session?')) return;
    try {
        const res = await fetch(`${API_BASE}/faculty/sessions/${sessionId}/complete`, {
            method: 'POST',
            headers: getAuthHeaders()
        });
        if (res.ok) {
            showToast('Session completed successfully!', 'success');
            loadFacultyDashboard();
        } else {
            const data = await res.json();
            showToast(data.detail || 'Error completing session', 'error');
        }
    } catch (e) { showToast('Network error', 'error'); }
}

async function loadFacultyTimetable() {
    const tbody = document.getElementById('table-my-timetable-body');
    try {
        const res = await fetch(`${API_BASE}/faculty/timetable`, { headers: getAuthHeaders() });
        const data = await res.json();
        const list = data.timetable || [];

        tbody.innerHTML = list.map(item => `
            <tr>
                <td><strong>${item.day_of_week}</strong></td>
                <td>${item.period_name}</td>
                <td><span class="time-pill">${item.start_time} - ${item.end_time}</span></td>
                <td><span class="tag tag-info">${item.subject_code}</span> ${item.subject_name}</td>
                <td><strong>${item.class_name}</strong></td>
            </tr>
        `).join('');
    } catch (e) {}
}
