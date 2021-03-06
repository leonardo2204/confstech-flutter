import 'dart:async';

import 'package:confs_tech/blocs/bloc.dart';
import 'package:confs_tech/models/event_response.dart';
import 'package:confs_tech/repositories/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'event_event.dart';
import 'event_state.dart';

class EventBloc extends Bloc<EventEvent, EventState> {
  final EventRepository eventRepository;
  final FilteredEventsBloc filteredEventsBloc;
  StreamSubscription filteredEventsSubscription;

  EventBloc({@required this.eventRepository, @required this.filteredEventsBloc})
      : super(EventLoading()) {
    filteredEventsSubscription = filteredEventsBloc.listen((state) {
      if (state is FilteredEventsLoaded) {
        add(FetchEvent(
            filters: state.selectedFilters,
            searchQuery: state.searchQuery,
            showCallForPapers: state.showCallForPapers,
            showPast: state.showPast));
      }
    });
  }

  @override
  Future<void> close() {
    filteredEventsSubscription?.cancel();
    return super.close();
  }

  @override
  Stream<EventState> mapEventToState(EventEvent event) async* {
    final currentState = state;

    if (event is FetchEvent) {
      try {
        yield EventLoading();
        EventResponse response = await this.eventRepository.getEvents(
            event.searchQuery,
            event.page,
            event.filters,
            event.showCallForPapers,
            event.showPast);

        if (response.events.length == 0) {
          yield EventEmpty();
        } else {
          print(response.events[0].toString());
          yield EventLoaded(
              event: response.events,
              hasMore: response.hasMore,
              currentQuery: event.searchQuery,
              currentPage: response.page,
              selectedFilters: response.selectedFilters,
              showCallForPapers: event.showCallForPapers,
              showPast: event.showPast);
        }
      } catch (e) {
        print(e);
        yield EventError();
      }
    } else if (event is LoadMoreEvent && _hasMore(currentState)) {
      try {
        if (currentState is EventLoaded) {
          EventResponse response = await this.eventRepository.getEvents(
              currentState.currentQuery,
              currentState.currentPage + 1,
              currentState.selectedFilters,
              currentState.showCallForPapers,
              currentState.showPast);

          if (response.events.length == 0) {
            yield currentState.copyWith(hasMore: false);
          } else {
            yield currentState.copyWith(
              events: currentState.event + response.events,
              hasMore: response.hasMore,
              currentPage: currentState.currentPage + 1,
            );
          }
        }
      } catch (e) {
        yield EventError();
      }
    }
  }

  bool _hasMore(EventState state) {
    return state is EventLoaded && state.hasMore;
  }
}
