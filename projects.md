---
layout: page
title: Projects
description: Opsis and RoleSmith project pages with markdown docs
---

# Projects

{% assign sorted_projects = site.projects | sort: 'title' %}

<div class="features-grid">
  {% for project in sorted_projects %}
  <div class="feature-card">
    <h3>{% if project.icon %}{{ project.icon }} {% endif %}{{ project.title }}</h3>
    {% if project.tagline %}
    <p>{{ project.tagline }}</p>
    {% endif %}

    {% if project.tech_stack %}
    <p>
      {% for tech in project.tech_stack limit: 6 %}
      <code>{{ tech }}</code>{% unless forloop.last %} {% endunless %}
      {% endfor %}
    </p>
    {% endif %}

    <p>
      <a href="{{ project.url | relative_url }}">Open project page</a>
      {% if project.docs_url %}<span aria-hidden="true"> • </span><a href="{{ project.docs_url | relative_url }}">View Project Documents</a>{% endif %}
    </p>
  </div>
  {% endfor %}
</div>
