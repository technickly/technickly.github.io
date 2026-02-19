---
layout: page
title: Projects
description: Explore the different type of AI projects
permalink: /projects/
---

{% assign sorted_projects = site.projects | sort: 'title' %}

<div class="features-grid">
  {% for project in sorted_projects %}
  <div class="feature-card">
    <h3>{% if project.icon %}{{ project.icon }} {% endif %}{{ project.title }}</h3>
    {% if project.title == "Opsis" %}
    <p>Opsis is a containerized local AI Jira ticket first responder that uses a RAG workflow to answer from relevant internal knowledge, not hallucinated guesses.</p>
    {% elsif project.tagline %}
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
      <a class="btn btn-project" href="{{ project.url | relative_url }}">Go to Project</a>
    </p>
  </div>
  {% endfor %}
</div>
