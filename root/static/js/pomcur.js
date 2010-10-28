Array.prototype.last = function() {return this[this.length-1];}

$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  });
});

var pomcur = {
  ontology_complete_url : application_root + '/ws/lookup/go/' + current_component,

  term_history : [],

  use_term_data : function(data) {
    var term = data[0];

    $('#ferret').data('current-term', term);

    $('#ferret-term-name').text(term.name);
    $('#ferret-term-definition').text(term.definition);

    var children = term.children;
    var children_html = '';

    $.each(children, function(idx, child) {
      children_html += '<li><a href="#' + child.id + '">' + child.name + '</a></li>';
    });

    $('#ferret-term-children').data('child-count', children.length);
    $('#ferret-term-children-list').html($('<ul/>').append($(children_html)));

    if (children.length == 0) {
      pomcur.show_leaf();
    } else {
      pomcur.show_children();
    }

    pomcur.hide_accept();
  },

  set_details : function(term_id) {
    pomcur.hide_children();
    var stored_term_id = $('#ferret-term-id').val();
    if (stored_term_id != term_id) {
      $('#ferret-term-id').val(term_id);
    }
    $.ajax({
      url: pomcur.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
      dataType: 'json',
      success: pomcur.use_term_data,
      async: false
    });
    $('#ferret-term-entry').hide();
  },

  term_selected : function(term_id) {
    $('#ferret-term-id').val(term_id);
    $('.ferret-term-id-display').text(term_id);
    $('#ferret-term-details').show();

    if (pomcur.term_history.length > 0) {
      $('#ferret-previous-button').show();
      $('#ferret-reset-button').hide();
    } else {
      $('#ferret-previous-button').hide();
      $('#ferret-reset-button').show();
    }
    pomcur.set_details(term_id);
  },

  add_to_breadcrumbs : function(term) {
    var breadcrumbs_ul = $('#breadcrumbs ul')
    var li = $('<li class="hash-term">&gt;<a title="' +
               term.name + '" href="#' + term.id + '">' +
               term.id + "</a></li>");
    li.data('term', term);
    breadcrumbs_ul.append(li);
  },

  add_history : function(term) {
    pomcur.term_history.push(term);
    pomcur.add_to_breadcrumbs(term);
  },

  truncate_history : function(term_id) {
    $('#breadcrumbs li.hash-term').remove();
    for (var i = 0; i < pomcur.term_history.length; i++) {
      var this_term = pomcur.term_history[i];
      if (this_term.id == term_id) {
        pomcur.term_history.length = i;
        break;
      } else {
        pomcur.add_to_breadcrumbs(this_term);
      }
    };
  },

  pop_history : function() {
    var last_id = pomcur.term_history.last().id;
    pomcur.truncate_history(last_id);
    pomcur.term_selected(last_id);
    pomcur.show_hide_children();
    pomcur.hide_accept();
    return false;
  },

  ignore_children : function() {
    pomcur.hide_child_details();
    pomcur.show_accept();
    return false;
  },

  show_accept : function() {
    $('#ferret-accept-term-details').show();
  },

  hide_accept : function() {
    $('#ferret-accept-term-details').hide();
  },

  move_to_hash_term : function(link) {
    var href = link.attr('href');
    var term_id = href.substring(href.indexOf('#') + 1);
    pomcur.truncate_history(term_id);
    pomcur.term_selected(term_id);
  },

  term_click_handler : function(event) {
    pomcur.move_to_hash_term($(event.target));
    pomcur.hide_children();
    var leaf = $('#ferret-leaf');
    leaf.hide();
    return false;
  },

  child_click_handler : function(event) {
    pomcur.add_history($('#ferret').data('current-term'));
    pomcur.move_to_hash_term($(event.target));
    return false;
  },

  current_child_count : function() {
    var term_children = $('#ferret-term-children');
    return term_children.data('child-count');
  },

  show_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.show();
    pomcur.hide_leaf();
    pomcur.show_child_details();
  },

  hide_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.hide();
  },

  show_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.show();
    pomcur.hide_children();
    pomcur.show_child_details();
  },

  hide_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.hide();
  },

  hide_child_details: function() {
    $('#ferret-children-details').hide();
  },

  show_child_details: function() {
    $('#ferret-children-details').show();
  },

  show_hide_children : function() {
    if (pomcur.current_child_count() > 0) {
      pomcur.show_children();
    } else {
      pomcur.hide_children();
    }
  },

  suggest_dialog : function() {
    $('#ferret-suggest-form').dialog({ modal: true,
                                       title: 'Suggest a new term' });
    return false;
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    pomcur.hide_child_details();
    $('#ferret-term-details').hide();
    $('#ferret-term-entry').show();
    pomcur.hide_accept();
    return true;
  }
};


$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    ferret_input.autocomplete({
      minLength: 2,
      source: pomcur.ontology_complete_url,
      focus: function(event, ui) {
        $('#ferret-term-input').val(ui.item.name);
        pomcur.hide_confirm();
        return false;
      },
      select: function(event, ui) {
        pomcur.term_selected(ui.item.id);
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + item.name + " <span class='term-id'>(" + item.id + ")</span></a>" )
        .appendTo( ul );
    };
  }

  $("body").delegate("#ferret-term-children-list a", "click",
                     pomcur.child_click_handler);
  $("body").delegate("#breadcrumbs li.hash-term a", "click",
                     pomcur.term_click_handler);

  $("#ferret-reset-button").click(pomcur.ferret_reset);
  $("#ferret-previous-button").click(pomcur.pop_history);
  $("#ferret-ignore-children").click(pomcur.ignore_children);

  var form_success = function(responseText, statusText, xhr, $form) {
    if (responseText == 'term-selected') {
      pomcur.show_hide_children();
    }
    return true;
  };
  $('#ferret-form').ajaxForm({ success: form_success, async: false });
  $('#ferret-term-input').attr('disabled', false);

  $('#ferret-suggest-link').click(pomcur.suggest_dialog);
  $('#ferret-suggest-link-leaf').click(pomcur.suggest_dialog);

});
